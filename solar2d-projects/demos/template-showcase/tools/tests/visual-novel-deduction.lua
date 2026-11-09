-- Verdict rule cases and a touch play-through of visual-novel-deduction under the Solar2D stub.
-- Usage, from the demo root: lua5.1 tools/tests/visual-novel-deduction.lua
local lfs = require( "lfs" )

local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. package.path

local failures, checks = 0, 0

local function check( condition, message )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. message )
	end
end

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/visual-novel-deduction" )

-- Verdict rule, headless.
local accusation = require( "samples.visual-novel-deduction.classes.accusation" )
local settings = require( "samples.visual-novel-deduction.data.settings" )
local case = settings.case

local function copyLinks( changes )
	local links = {}
	for clueId, suspectId in pairs( case.solution ) do
		links[clueId] = suspectId
	end
	for clueId, suspectId in pairs( changes ) do
		links[clueId] = suspectId or nil
	end
	return links
end

check( accusation.judge( copyLinks( {} ), case ) == "right", "all six right" )
check( accusation.judge( copyLinks( { clueBox = "mae" } ), case ) == "partlyRight", "ticket right, one wrong" )
check( accusation.judge( copyLinks( { clueBox = false, clueKey = false } ), case ) == "partlyRight", "ticket right, links missing" )
check( accusation.judge( { clueTicket = "vivian" }, case ) == "partlyRight", "ticket only" )
check( accusation.judge( copyLinks( { clueTicket = "jimmy" } ), case ) == "wrong", "ticket to Jimmy" )
check( accusation.judge( copyLinks( { clueTicket = false } ), case ) == "wrong", "ticket unlinked" )
check( accusation.judge( {}, case ) == "wrong", "no links" )

-- Scene play-through.
local function steps( count )
	for _ = 1, count do
		stub.step()
	end
end

local function press( keyName )
	stub.call( stub.key, keyName, "down", false )
	steps( 1 )
	stub.call( stub.key, keyName, "up", false )
	steps( 1 )
end

local function click( x, y )
	stub.call( stub.touchAt, x, y, "began" )
	stub.call( stub.touchAt, x, y, "ended" )
	steps( 1 )
end

local function each( group, visit )
	for i = 1, ( group.numChildren or 0 ) do
		local child = group[i]
		visit( child )
		each( child, visit )
	end
end

local function isShown( object )
	while object do
		if not object.isVisible then
			return false
		end
		object = object.parent
	end
	return true
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.visual-novel-deduction.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
steps( 2 )

local view = scene.view

local function screenText()
	local parts = {}
	each( view, function( object )
		if type( object.text ) == "string" and object.text ~= "" and isShown( object ) then
			parts[#parts + 1] = object.text
		end
	end )
	return table.concat( parts, " | " )
end

local function shows( text )
	return string.find( screenText(), text, 1, true ) ~= nil
end

local function countShown( kind, filenamePart )
	local count = 0
	each( view, function( object )
		local internal = rawget( object, "_stub" )
		if internal and internal.kind == kind and isShown( object ) and ( not filenamePart or string.find( internal.filename or "", filenamePart, 1, true ) ) then
			count = count + 1
		end
	end )
	return count
end

local function advanceUntil( text, limit )
	for _ = 1, limit or 40 do
		if shows( text ) then
			return true
		end
		press( "space" )
	end
	return shows( text )
end

local positions = {}
for i = 1, #settings.board.suspects do
	local suspect = settings.board.suspects[i]
	positions[suspect.id] = suspect
end
for i = 1, #settings.board.clues do
	local clue = settings.board.clues[i]
	positions[clue.id] = clue
end

local emptyCork = { x = 372, y = 342 }

local function drag( fromId, to, inspect )
	local from = positions[fromId]
	stub.call( stub.touchAt, from.x, from.y, "began" )
	stub.call( stub.touchAt, ( from.x + to.x ) * 0.5, ( from.y + to.y ) * 0.5, "moved", from.x, from.y )
	if inspect then
		inspect()
	end
	stub.call( stub.touchAt, to.x, to.y, "moved", from.x, from.y )
	stub.call( stub.touchAt, to.x, to.y, "ended", from.x, from.y )
	steps( 1 )
end

local function linkAll( links )
	for clueId, suspectId in pairs( links ) do
		drag( clueId, positions[suspectId] )
	end
end

local function reachBoard( label )
	check( shows( "You're late. Again." ), label .. ": opening starts in the office" )
	check( countShown( "line" ) == 0, label .. ": no strings during the opening" )
	check( advanceUntil( settings.hint.board ), label .. ": board reached" )
	check( shows( "Links 0/6" ) and shows( "Accuse" ), label .. ": counter and Accuse shown" )
	check( countShown( "imageRect", "corkboard" ) == 1, label .. ": corkboard is the background" )
end

local function finishVerdict( firstLine, label )
	click( settings.accuse.x, settings.accuse.y )
	check( shows( firstLine ), label .. ": verdict passage plays" )
	check( not shows( "Links" ) and not shows( "Accuse" ), label .. ": board controls hidden" )
	local before = countShown( "line" )
	drag( "clueMatchbook", positions.vivian )
	check( countShown( "line" ) == before, label .. ": no linking during the verdict" )
	check( advanceUntil( "Commissioner Briggs" ), label .. ": Briggs speaks" )
	check( countShown( "imageRect", "commissioner" ) == 1, label .. ": Briggs on stage" )
	check( advanceUntil( "Play again" ), label .. ": Play again offered" )
end

-- Run 1: link, replace, remove, drop on empty cork, partly right.
reachBoard( "run 1" )
check( advanceUntil( settings.hint.board, 1 ), "Space keeps the board" )
click( 480, 300 )
check( shows( "Links 0/6" ), "click on empty cork links nothing" )

drag( "clueTicket", positions.vivian, function()
	check( countShown( "line" ) == 1, "string follows the finger during a drag" )
end )
check( shows( "Links 1/6" ) and countShown( "line" ) == 1, "first link pinned" )

linkAll( { cluePhoto = "vivian", clueKey = "vivian", clueCard = "jimmy", clueBox = "jimmy", clueMatchbook = "mae" } )
check( shows( "Links 6/6" ) and countShown( "line" ) == 6, "six links pinned" )

drag( "clueCard", positions.mae )
check( shows( "Links 6/6" ) and countShown( "line" ) == 6, "relinking a clue replaces its string" )

drag( "clueBox", emptyCork )
check( shows( "Links 5/6" ) and countShown( "line" ) == 5, "dragging a string off removes the link" )

drag( "clueBox", emptyCork )
check( shows( "Links 5/6" ) and countShown( "line" ) == 5, "dropping an unlinked clue on the cork does nothing" )

click( positions.clueMatchbook.x, positions.clueMatchbook.y )
check( shows( "Links 4/6" ), "a tap on a linked clue removes its link" )

finishVerdict( "The ticket puts the gem in a pawnshop under her name.", "partly right" )
check( shows( "Next time finish the board." ), "partly right: secretary closes" )

-- Run 2: Play again resets, then all right.
click( settings.playAgain.x, settings.playAgain.y )
reachBoard( "run 2" )
linkAll( case.solution )
check( shows( "Links 6/6" ), "run 2: six links" )
finishVerdict( "Vivian Ash pawned her own gem and called it a theft.", "right" )

-- Run 3 by keyboard restart: ticket to Jimmy is wrong.
press( "space" )
reachBoard( "run 3" )
linkAll( { clueTicket = "jimmy", cluePhoto = "vivian" } )
finishVerdict( "It has to be the lawyer.", "wrong" )
check( shows( "Mrs. Ash sent flowers." ), "wrong: secretary closes" )

-- Run 4: no links at all is wrong too.
click( settings.playAgain.x, settings.playAgain.y )
reachBoard( "run 4" )
click( settings.accuse.x, settings.accuse.y )
check( shows( "It has to be the lawyer." ), "no links: wrong verdict" )

-- Hide during a drag releases the focus and removes the drag string; re-entering starts fresh.
click( settings.playAgain.x, settings.playAgain.y )
advanceUntil( "Play again" )
click( settings.playAgain.x, settings.playAgain.y )
reachBoard( "run 5" )
drag( "clueKey", positions.vivian )
stub.call( stub.touchAt, positions.clueTicket.x, positions.clueTicket.y, "began" )
stub.call( stub.touchAt, 300, 300, "moved", positions.clueTicket.x, positions.clueTicket.y )
check( stub.focus ~= nil, "drag holds the touch focus" )
stub.sceneEvent( scene, "hide", "will" )
check( stub.focus == nil, "hide releases the touch focus" )
check( countShown( "line" ) == 1, "hide removes the drag string" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
reachBoard( "re-entered" )
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )
check( rawget( _G, "WEAVERxRosoNoirDeduction" ) == nil, "Weaver cache cleared on destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
