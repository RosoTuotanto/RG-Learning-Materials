-- Drives the real hidden-object scene under the harness stub and prints only failures and a summary count.
-- Usage, from the demo root: lua5.1 tools/tests/visual-novel-hidden-object.lua

local lfs = require( "lfs" )
local harness = lfs.currentdir() .. "/tools/harness"
package.path = "./?.lua;" .. harness .. "/?.lua;" .. package.path

local stub = dofile( harness .. "/stub/solar2d.lua" )
local temporaryRoot = ".scratch/tmp/visual-novel-hidden-object"
stub.install( harness, temporaryRoot )
stub.call( dofile, "main.lua" )

local settings = require( "samples.visual-novel-hidden-object.data.settings" )
local scene = require( "samples.visual-novel-hidden-object.demo" )

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. message )
	end
end

local function frames( count )
	for _ = 1, count do
		stub.step()
	end
end

local function walk( object, visit )
	visit( object )
	if object.numChildren then
		for i = 1, object.numChildren do
			walk( object[i], visit )
		end
	end
end

local function shownTexts()
	local texts = {}
	walk( scene.view, function( object )
		if type( object.text ) == "string" and object.text ~= "" then
			local shown, node = true, object
			while node do
				if node.isVisible == false then
					shown = false
				end
				node = node.parent
			end
			if shown then
				texts[object.text] = true
			end
		end
	end )
	return texts
end

local function hitAreas()
	local found = {}
	walk( scene.view, function( object )
		if object.sprite then
			found[object.sprite.clue.id] = object
		end
	end )
	return found
end

local function click( x, y )
	stub.touchAt( x, y, "began" )
	stub.touchAt( x, y, "ended" )
	frames( 1 )
end

local function counter( n )
	return string.format( settings.counter.format, n, #settings.search.clues )
end

local emptySpots = { { 700, 150 }, { 560, 120 }, { 820, 470 }, { 60, 300 } }

local function sceneEvent( name, phase )
	stub.sceneEvent( scene, name, phase )
end

sceneEvent( "create" )
sceneEvent( "show", "will" )
sceneEvent( "show", "did" )
frames( 2 )

-- Clues and covers sit in one room group at the bottom of the character layer, below every character on stage.
local room = hitAreas().clueBox.sprite.parent.parent

local function checkRoomBelowCharacters( when, characterCount )
	local characterLayer = room.parent
	check( characterLayer[1] == room and characterLayer.numChildren == characterCount + 1,
		when .. ": room below " .. characterCount .. " characters (layer holds " .. characterLayer.numChildren .. ")" )
end

checkRoomBelowCharacters( "opening", 2 )

local function playOpening()
	check( shownTexts()["You're late. Again."], "opening first line shown" )
	local clicks = 0
	while not shownTexts()[settings.hint.search] and clicks < 40 do
		click( 700, 150 )
		clicks = clicks + 1
	end
	check( clicks == 14, "opening took " .. clicks .. " clicks, expected 14" )
	check( shownTexts()[counter( 0 )], "counter 0 shown after the opening" )
end

playOpening()

-- A click on the strip above the box, inside the box's unclamped padding, finds nothing.
local stripTop = settings.strip.panel.y - settings.strip.panel.height * 0.5
local boxArea = hitAreas().clueBox
check( boxArea.y + boxArea.height * 0.5 <= stripTop, "box hit area clamped at the strip top" )
click( boxArea.x, stripTop + 6 )
frames( 30 )
check( boxArea.isHitTestable and shownTexts()[counter( 0 )], "strip click did not find the box" )

-- Empty space during the search does nothing.
for i = 1, #emptySpots do
	click( emptySpots[i][1], emptySpots[i][2] )
end
frames( 30 )
check( shownTexts()[settings.hint.search] and shownTexts()[counter( 0 )], "empty clicks changed nothing" )

local remarks = {
	clueMatchbook = "Mae's. Somebody needed light in here and didn't want the lamp on.",
	cluePhoto = "A bank notice on a rich woman's door. That's a rich woman with a problem.",
	clueKey = "Not my key. Not my coat pocket's usual company either.",
	clueTicket = "Yesterday morning. Funny time to pawn a gem that was stolen last night.",
	clueCard = "Jimmy leaves these everywhere. This time he left one at a break-in.",
	clueBox = "A thief takes the stone and leaves the box. Somebody packed this.",
}
local order = { "clueBox", "clueCard", "clueKey", "cluePhoto", "clueTicket", "clueMatchbook" }
local panel = settings.strip.panel

for n = 1, #order do
	local id = order[n]
	local areas = hitAreas()
	local area = areas[id]
	local sprite = area.sprite

	-- Near the bottom-left corner of the hit area, inside the padding: the visible corner of the photo and card.
	local x = area.x - area.width * 0.5 + 3
	local y = area.y + area.height * 0.5 - 3
	click( x, y )

	-- A click on another clue during the flight is ignored.
	local other = order[n + 1] and areas[order[n + 1]]
	if other then
		click( other.x, other.y )
	end
	frames( 40 )

	local texts = shownTexts()
	check( texts[remarks[id]], id .. " remark shown" )
	check( texts[counter( n )], id .. " counter shows " .. n )
	check( texts[settings.hint.story] and not texts[settings.hint.search], id .. " story hint during the remark" )
	local slotX = panel.x + ( n - 3.5 ) * settings.strip.slotSpacing
	check( math.abs( sprite.x - slotX ) < 0.01 and math.abs( sprite.y - panel.y ) < 0.01, id .. " landed in slot " .. n )
	check( not area.isHitTestable, id .. " hit area off" )
	if other then
		check( other.isHitTestable, order[n + 1] .. " still unfound after the click during the flight" )

		-- A click on the next clue while the remark plays advances the story instead of finding it.
		click( other.x, other.y )
		check( other.isHitTestable and shownTexts()[counter( n )], order[n + 1] .. " not found by a click during the remark" )
		check( shownTexts()[settings.hint.search], id .. " search resumes after the remark" )

		-- A second click on the found clue's spot and on its slot does nothing.
		click( sprite.homeX, sprite.homeY )
		click( slotX, panel.y )
		frames( 30 )
		check( shownTexts()[counter( n )] and shownTexts()[settings.hint.search], id .. " second click did nothing" )
	end
end

-- The last remark leads into the closing passage.
click( 700, 150 )
check( shownTexts()["Her box. Her key. A pawn ticket in her name. And Jimmy's card on top."], "closing passage starts" )
checkRoomBelowCharacters( "closing", 2 )
for _ = 1, 4 do
	stub.key( "space", "down" )
	stub.key( "space", "up" )
end
check( shownTexts()["Mrs. Ash wasn't robbed. Get my hat. We're going to Dock Street."], "closing last line" )
click( 700, 150 )
check( shownTexts()[settings.playAgain.label], "Play again shown" )

-- Play again starts a fresh story.
click( settings.playAgain.x, settings.playAgain.y )
local areas = hitAreas()
local fresh = shownTexts()["You're late. Again."] and not shownTexts()[counter( 6 )] and not shownTexts()[settings.playAgain.label]
for _, area in pairs( areas ) do
	fresh = fresh and area.isHitTestable and area.sprite.x == area.sprite.homeX
end
check( fresh, "Play again restarts cleanly" )

-- Second round: find two clues, leave mid-flight, come back fresh.
playOpening()
click( areas.clueTicket.x, areas.clueTicket.y )
frames( 40 )
click( 700, 150 )
click( areas.clueKey.x, areas.clueKey.y )
frames( 5 )
sceneEvent( "hide", "will" )
check( stub.activeTransitionCount() == 0, "transition cancelled on hide" )
sceneEvent( "hide", "did" )
frames( 30 )
sceneEvent( "show", "will" )
sceneEvent( "show", "did" )
frames( 2 )
local reset = shownTexts()["You're late. Again."] and not shownTexts()[counter( 1 )]
for _, area in pairs( hitAreas() ) do
	reset = reset and area.isHitTestable and area.sprite.x == area.sprite.homeX
end
check( reset, "re-entering starts fresh" )
playOpening()

sceneEvent( "hide", "will" )
sceneEvent( "hide", "did" )
sceneEvent( "destroy" )
check( _G["WEAVERx" .. settings.story.name] == nil, "Weaver cache cleared on destroy" )

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end
for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end
os.execute( "rm -rf '" .. temporaryRoot .. "'" )
print( ( failures == 0 and "OK " or "FAIL " ) .. checks .. " checks, " .. failures .. " failures" )
