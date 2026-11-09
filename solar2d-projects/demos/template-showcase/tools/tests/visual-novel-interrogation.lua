-- Play-through of visual-novel-interrogation with key and touch events under the Solar2D stub.
-- Usage, from the demo root: lua5.1 tools/tests/visual-novel-interrogation.lua
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
stub.install( harnessDirectory, ".scratch/tmp/visual-novel-interrogation" )

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
local _, scene = stub.call( require, "samples.visual-novel-interrogation.demo" )
local settings = require( "samples.visual-novel-interrogation.data.settings" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
steps( 2 )

local view = scene.view

-- Every visible text on screen, joined, so lines can be searched.
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

local function foundMarks()
	local found, total = 0, 0
	each( view, function( object )
		local internal = rawget( object, "_stub" )
		if internal and internal.kind == "circle" and isShown( object ) then
			total = total + 1
			if internal.fillColor and internal.fillColor[1] == settings.contradictions.foundColour[1] then
				found = found + 1
			end
		end
	end )
	return found, total
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

local statementLines = {
	"The Crimson Heart sat in its case all day yesterday.",
	"The thief forced my display case open.",
	"this isn't about money.",
}

local pressPointers = {
	"Then I'd like another look at that pawn ticket.",
	"I've seen a key like that today.",
	"Then let's look at that torn photo of your front door again.",
}

local nudges = {
	"What I want says where your gem was yesterday morning.",
	"What I want opens your display case.",
	"What I want shows your front door.",
}

local brokenLines = {
	"Your gem spent yesterday in a pawnshop safe, not in its case.",
	"Nobody forced anything. The case was opened with its own key.",
	"The bank is taking your house, Mrs. Ash.",
}

local statementCount = #settings.statements
local testimonyHint = settings.hint.testimony
local panelLayout = settings.evidencePanel
local panelTop = panelLayout.y - panelLayout.height * 0.5
local closeX = panelLayout.x + panelLayout.width * 0.5 - panelLayout.closeInset - panelLayout.closeWidth * 0.5
local presentX = 561

local function rowY( clueIndex )
	return panelTop + panelLayout.firstRowOffset + ( clueIndex - 1 ) * panelLayout.rowSpacing
end

local function clueIndexOf( id )
	for i = 1, #settings.clues do
		if settings.clues[i].id == id then
			return i
		end
	end
end

local function presentByTouch( id )
	click( presentX, 462 )
	click( panelLayout.x, rowY( clueIndexOf( id ) ) )
end

local function counter( index )
	return string.format( settings.testimony.counterFormat, index, statementCount )
end

-- Opening
check( shows( "You're late. Again." ), "opening starts with the secretary" )
check( select( 2, foundMarks() ) == 0, "marks hidden during the opening" )
check( advanceUntil( "She's outside the door." ), "opening close reached" )
check( advanceUntil( statementLines[1] ), "testimony starts at statement 1" )
check( shows( testimonyHint ), "testimony hint shown" )
check( shows( counter( 1 ) ), "counter shows statement 1" )
check( statementCount == 3 and #settings.clues == 3, "three statements and three clues" )

local found, total = foundMarks()
check( found == 0 and total == statementCount, "one open mark per statement at testimony start" )

-- Space and clicks on the stage do not leave the statement.
press( "space" )
click( 480, 200 )
check( shows( statementLines[1] ) and shows( testimonyHint ), "statement stays on Space and stage click" )

-- Navigation wraps both ways.
press( "left" )
check( shows( statementLines[3] ) and shows( counter( 3 ) ), "Left from 1 wraps to 3" )
press( "right" )
check( shows( statementLines[1] ), "Right from 3 wraps to 1" )

-- Every press runs its passage, points at the clue that breaks the statement, and returns to it.
for i = 1, statementCount do
	if i > 1 then
		press( "right" )
	end
	check( shows( statementLines[i] ), "statement " .. i .. " shown before press" )
	press( "p" )
	check( not shows( testimonyHint ), "testimony controls hidden during press " .. i )
	check( advanceUntil( pressPointers[i] ), "press " .. i .. " points at its clue" )
	check( advanceUntil( statementLines[i], 3 ), "press " .. i .. " returns to statement " .. i )
	check( shows( testimonyHint ), "testimony controls back after press " .. i )
end

-- Present button by touch opens the panel with every description; a backdrop click closes nothing.
click( presentX, 462 )
check( shows( panelLayout.title ), "Present button opens the evidence panel" )
for i = 1, #settings.clues do
	check( shows( settings.clues[i].name ) and shows( settings.clues[i].description ), "panel shows " .. settings.clues[i].id .. " with its description" )
end
click( 900, 600 )
click( panelLayout.x, panelTop + 48 )
check( shows( panelLayout.title ), "clicks on the backdrop and the panel box keep the panel open" )
click( closeX, panelTop + panelLayout.titleOffset )
check( not shows( panelLayout.title ), "Close button closes the panel" )

-- Two quick clicks on Present leave the panel open.
click( presentX, 462 )
click( presentX, 462 )
check( shows( panelLayout.title ) and shows( statementLines[3] ), "double click on Present keeps the panel open" )
click( closeX, panelTop + panelLayout.titleOffset )

-- E and Escape.
press( "e" )
check( shows( panelLayout.title ), "E opens the panel" )
press( "escape" )
check( not shows( panelLayout.title ), "Escape closes the panel" )
check( shows( statementLines[3] ), "still on statement 3 after closing" )

-- Every wrong clue on every statement plays that statement's nudge and costs nothing; the first by keyboard, the rest by touch.
press( "right" )
local usedKeyboard = false
for i = 1, statementCount do
	local rightClue = clueIndexOf( settings.statements[i].brokenBy )
	for clueIndex = 1, #settings.clues do
		if clueIndex ~= rightClue then
			if usedKeyboard then
				click( presentX, 462 )
				click( panelLayout.x, rowY( clueIndex ) )
			else
				press( "e" )
				for _ = 2, clueIndex do
					press( "down" )
				end
				press( "enter" )
				usedKeyboard = true
			end

			local label = "clue " .. clueIndex .. " on statement " .. i
			check( advanceUntil( "Darling, what is that supposed to be?", 2 ), "wrong " .. label .. " gets Vivian's reply" )
			check( advanceUntil( nudges[i], 2 ), "wrong " .. label .. " nudges toward the right clue" )
			check( advanceUntil( statementLines[i], 3 ) and shows( testimonyHint ), "back to statement " .. i .. " after wrong " .. label )
			check( foundMarks() == 0 and not shows( settings.endButton.label ), "wrong " .. label .. " costs nothing" )
		end
	end
	press( "right" )
end
check( shows( statementLines[1] ), "back on statement 1 after the wrong presentations" )

-- The full solve: statement 1 by keyboard, the others by touch.
press( "e" )
for _ = 2, clueIndexOf( "clueTicket" ) do
	press( "down" )
end
press( "enter" )
check( advanceUntil( "A pawn ticket from Kessler Loans.", 2 ), "the ticket breaks statement 1" )
check( foundMarks() == 1, "statement 1 fills one mark" )
check( advanceUntil( brokenLines[1] ), "broken 1 explains the contradiction" )
check( advanceUntil( statementLines[2], 4 ) and shows( counter( 2 ) ), "testimony moves on to statement 2" )

press( "left" )
check( shows( statementLines[3] ), "Left from 2 skips broken statement 1" )
press( "right" )
check( shows( statementLines[2] ), "Right from 3 skips broken statement 1" )

-- An item that already broke a statement is only wrong on another one.
presentByTouch( "clueTicket" )
check( advanceUntil( nudges[2], 3 ), "the used ticket on statement 2 gets statement 2's nudge" )
check( advanceUntil( statementLines[2], 3 ) and foundMarks() == 1, "the used ticket leaves statement 2 open and the marks unchanged" )

click( presentX, 462 )
click( panelLayout.x, rowY( clueIndexOf( "clueKey" ) ) )
check( advanceUntil( brokenLines[2], 3 ), "the key breaks statement 2" )
check( foundMarks() == 2, "statement 2 fills a second mark" )
check( advanceUntil( statementLines[3], 3 ), "testimony moves on to statement 3" )

press( "right" )
check( shows( statementLines[3] ), "only statement 3 is left" )

click( presentX, 462 )
click( panelLayout.x, rowY( clueIndexOf( "cluePhoto" ) ) )
check( advanceUntil( brokenLines[3], 3 ), "the photo breaks statement 3" )
check( foundMarks() == 3, "every mark filled" )
check( advanceUntil( "Three statements, three lies." ), "breakthrough starts after the last break" )
check( not shows( testimonyHint ), "testimony controls hidden in the breakthrough" )
check( advanceUntil( "So would the police." ), "breakthrough reaches its last line" )
check( advanceUntil( settings.endButton.label ), "Play again offered" )
check( shows( "The pawn ticket stays on the desk between them." ), "closing line stays on screen" )

-- Play again restarts from the opening.
click( settings.endButton.x, settings.endButton.y )
check( shows( "You're late. Again." ) and select( 2, foundMarks() ) == 0, "Play again replays the opening" )

-- A second solve after Play again starts with every statement open.
check( advanceUntil( statementLines[1] ) and foundMarks() == 0, "second run starts with no marks" )
press( "left" )
check( shows( statementLines[3] ), "second run has statement 3 open again" )

-- The second solve runs in reverse order, 3, 2, 1, with a used item presented on the way.
presentByTouch( "cluePhoto" )
check( advanceUntil( brokenLines[3], 3 ) and foundMarks() == 1, "reverse: the photo breaks statement 3" )
check( advanceUntil( statementLines[1], 4 ) and shows( counter( 1 ) ), "reverse: after 3 the testimony wraps to statement 1" )
press( "right" )
check( shows( statementLines[2] ), "reverse: Right from 1 reaches statement 2" )

presentByTouch( "cluePhoto" )
check( advanceUntil( nudges[2], 3 ), "reverse: the used photo on statement 2 gets statement 2's nudge" )
check( advanceUntil( statementLines[2], 3 ) and foundMarks() == 1, "reverse: statement 2 stays open after the used photo" )

presentByTouch( "clueKey" )
check( advanceUntil( brokenLines[2], 3 ) and foundMarks() == 2, "reverse: the key breaks statement 2" )
check( advanceUntil( statementLines[1], 4 ), "reverse: statement 1 is the only one left" )
press( "left" )
check( shows( statementLines[1] ), "reverse: Left stays on the last open statement" )

presentByTouch( "clueTicket" )
check( advanceUntil( brokenLines[1], 3 ) and foundMarks() == 3, "reverse: the ticket breaks statement 1" )
check( advanceUntil( "Three statements, three lies." ), "reverse: breakthrough after the last break" )
check( advanceUntil( settings.endButton.label ), "reverse: Play again offered" )

-- Hide and show again starts fresh.
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
check( shows( "You're late. Again." ), "re-entering starts fresh" )
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )
check( rawget( _G, "WEAVERxRosoNoirInterrogation" ) == nil, "Weaver cache cleared on destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
