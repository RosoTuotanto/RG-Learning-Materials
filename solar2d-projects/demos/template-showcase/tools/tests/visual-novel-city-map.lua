-- Play-through of visual-novel-city-map with key and touch events under the Solar2D stub.
-- Usage, from the demo root: lua5.1 tools/tests/visual-novel-city-map.lua
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
stub.install( harnessDirectory, ".scratch/tmp/visual-novel-city-map" )
stub.call( dofile, "main.lua" )

local prefix = "samples.visual-novel-city-map."
local settings = require( prefix .. "data.settings" )

-- Capture the scene's instances by wrapping the constructors before the scene requires them.
local player, map, clock
local storyPlayer = require( prefix .. "classes.storyPlayer" )
local cityMap = require( prefix .. "classes.cityMap" )
local dayClock = require( prefix .. "classes.dayClock" )
local newPlayer, newMap, newClock = storyPlayer.new, cityMap.new, dayClock.new
storyPlayer.new = function( params ) player = newPlayer( params ) return player end
cityMap.new = function( params ) map = newMap( params ) return map end
dayClock.new = function( params ) clock = newClock( params ) return clock end

local _, scene = stub.call( require, prefix .. "demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

local function steps( count )
	for _ = 1, count do
		stub.step()
	end
end

steps( 2 )

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

local area = settings.player.background
local spotsById = {}
for i = 1, #settings.map.spots do
	local spot = settings.map.spots[i]
	spotsById[spot.id] = spot
end

local function spotPoint( id )
	local scale = area.width / settings.map.pixelWidth
	local spot = spotsById[id]
	return area.x - area.width * 0.5 + spot.x * scale, area.y - area.height * 0.5 + spot.y * scale
end

local function variables()
	return _G["WEAVERx" .. settings.story.name].saveData
end

local function playAgainShown()
	local found = false
	local function visit( group )
		for i = 1, ( group.numChildren or 0 ) do
			local child = group[i]
			if child.text == settings.playAgain.label and child.parent.isVisible then
				found = true
			end
			visit( child )
		end
	end
	visit( scene.view )
	return found
end

-- Presses Space through the passage and returns every line shown, as "Speaker: text".
local function readPassage()
	local lines = {}
	local last

	for _ = 1, 60 do
		local line = player.speakerText.text .. ": " .. player.bodyText.text
		if line ~= last and player.isActive then
			lines[#lines + 1] = line
			last = line
		end
		if map.isOpen or playAgainShown() then
			break
		end
		press( "space" )
	end
	return table.concat( lines, "\n" )
end

local function has( text, part )
	return string.find( text, part, 1, true ) ~= nil
end

-- Clicks a spot, reads the passage, and checks the clock and the expected lines.
local function visit( id, expectedHour, parts, label )
	local x, y = spotPoint( id )
	click( x, y )
	local text = readPassage()
	check( clock.hour == expectedHour, label .. ": clock " .. clock.hour .. " expected " .. expectedHour )

	for i = 1, #parts do
		check( has( text, parts[i] ), label .. ": missing \"" .. parts[i] .. "\" in\n" .. text )
	end
	return text
end

local function clockText()
	return clock.text.text
end

local function opening()
	local text = readPassage()
	check( has( text, "Secretary: You're late. Again." ), "opening starts with the shared office lines" )
	check( has( text, "Secretary: Twelve hours. Don't spend them all at Mae's." ), "opening ends with this sample's close" )
	check( map.isOpen and clock.hour == 9 and clockText() == "9:00 Morning", "map opens at 9:00 Morning after the opening" )
end

local function playAgain()
	check( playAgainShown(), "Play again shown after the ending" )
	click( settings.playAgain.x, settings.playAgain.y )
	local saved = variables()
	check( clock.hour == 9 and not saved.knowsDebt and not saved.knowsMeeting and not saved.knowsPawn, "Play again resets time and flags" )
	check( not playAgainShown() and has( player.bodyText.text, "You're late. Again." ), "Play again replays the opening" )
end

opening()

-- Clicks during a passage advance the text and never start a trip.
do
	local x, y = spotPoint( "bar" )
	click( x, y )
	local before = player.bodyText.text
	local otherX, otherY = spotPoint( "precinct" )
	click( otherX, otherY )
	check( clock.hour == 10 and player.isActive and player.bodyText.text ~= before, "map click during a passage only advances the text" )
	stub.call( stub.touchObject, map.targets.precinct, otherX, otherY, "began" )
	check( clock.hour == 10 and player.isActive and not map.isOpen, "a spot touched directly during a passage does nothing" )
	readPassage()
	check( map.isOpen and clockText() == "10:00 Morning", "trip to the locked bar costs one hour" )
	visit( "precinct", 13, { "Commissioner Briggs: The lawyer's card" }, "precinct trip and talk cost three hours" )
end

-- Route to the "no pawn ticket" ending, restarted first so it begins at 9:00.
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
opening()

visit( "bar", 10, { "The door is locked.", "Mae: We open at noon. Come back thirsty." }, "C locked bar" )
check( not has( visit( "bar", 10, { "We open at noon." }, "C locked bar again" ), "Ten bucks" ), "C locked bar sells nothing" )
visit( "street", 13, { "Jimmy: Last night? Home. Alone." }, "C Jimmy refuses" )
check( not variables().knowsPawn, "C Jimmy gives nothing without the meeting" )
visit( "bar", 16, { "Mae: Ten bucks and I remember last night.", "She was never at the opera." }, "C Mae sells" )
check( variables().knowsMeeting == true, "C Mae sets knowsMeeting" )
visit( "bar", 18, { "Mae: You bought that already. I don't sell twice." }, "C Mae again" )
local emptyStreet = visit( "street", 19, { "The street is empty.", "Back tomorrow. Probably." }, "C evening street" )
check( not has( emptyStreet, "Jimmy:" ), "C evening street has no Jimmy" )
local lastBar = visit( "bar", 21, {
	"Briggs's men were in here", "You bought that already.", "Detective: Briggs picked up Jimmy at nine sharp.",
}, "C evening bar and ending" )
check( has( lastBar, "Briggs's men" ) and lastBar:find( "Briggs's men", 1, true ) < lastBar:find( "You bought", 1, true ), "C evening line comes first" )
check( clockText() == "21:00 Evening", "C talk past 21:00 stops at 21:00" )
playAgain()

-- Route to the full ending.
opening()
visit( "office", 11, { "The bank is selling the Ash house next month." }, "A office" )
visit( "bar", 14, { "Vivian Ash. Here at nine." }, "A bar" )
visit( "street", 17, { "Mae talks a lot for a woman who says so little.", "Ticket 4471." }, "A Jimmy" )
visit( "office", 20, { "A pawn ticket in her own name?", "It's getting late." }, "A office evening" )
visit( "precinct", 21, { "Kessler opened his safe at half past eight." }, "A trip to 21:00 goes straight to the ending" )
playAgain()

-- Route to the ending with the gem but no motive.
opening()
visit( "precinct", 12, { "The lawyer's card was on her hall table." }, "B precinct" )
visit( "bar", 15, { "Vivian Ash. Here at nine." }, "B bar" )
visit( "street", 18, { "Kessler Loans. Ticket 4471." }, "B Jimmy" )
check( variables().knowsPawn == true and not variables().knowsDebt, "B flags" )
visit( "street", 18, { "The street is empty." }, "B street again in the evening costs no time" )
local precinct = visit( "precinct", 21, {
	"I've got my coat on. Talk fast.", "I'll send a man to Dock Street.", "The gem turned up at Kessler's.",
}, "B evening precinct and ending" )
check( precinct:find( "coat on", 1, true ) < precinct:find( "Dock Street", 1, true ), "B coat line comes first" )
check( not has( precinct, "Kessler opened his safe" ), "B shows only its own ending" )

-- Jimmy's later-visit line, reached by setting the flags directly since the day leaves no afternoon after the pawn ticket.
variables().knowsPawn = true
variables().band = "afternoon"
player:jumpTo( "Street" )
check( has( player.bodyText.text, "If anyone asks, I was a concerned citizen." ), "Jimmy's later-visit line" )

-- The clock sits centred on the window's top edge, entirely on screen and clear of the map, at the content size and after resizes.
local function setScreen( originX, originY, width, height )
	display.screenOriginX = originX
	display.screenOriginY = originY
	display.actualContentWidth = width
	display.actualContentHeight = height
	stub.fireRuntime( { name = "resize" } )
end

local function checkClockPlacement( label )
	local mapImage = map.group[1]
	check( mapImage.width == area.width and mapImage.height == area.height, label .. ": map image found" )

	local clockBounds = clock.text.contentBounds
	local mapBounds = mapImage.contentBounds
	local overlapsX = clockBounds.xMin < mapBounds.xMax and clockBounds.xMax > mapBounds.xMin
	local overlapsY = clockBounds.yMin < mapBounds.yMax and clockBounds.yMax > mapBounds.yMin
	local overlaps = overlapsX and overlapsY
	check( not overlaps, label .. ": clock overlaps the map" )

	local screenCentreX = display.screenOriginX + display.actualContentWidth * 0.5
	check( math.abs( ( clockBounds.xMin + clockBounds.xMax ) * 0.5 - screenCentreX ) < 0.01, label .. ": clock is centred on the screen" )
	check( clockBounds.yMin >= display.screenOriginY, label .. ": clock stays below the top screen edge" )
end

checkClockPlacement( "960x640" )
setScreen( 0, -150, 960, 940 )
checkClockPlacement( "tall resize" )
setScreen( -200, 0, 1360, 640 )
checkClockPlacement( "wide resize" )
setScreen( 0, 0, 960, 640 )

stub.sceneEvent( scene, "hide", "will" )
-- Leaving and coming back starts fresh.
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
check( clock.hour == 9 and has( player.bodyText.text, "You're late. Again." ) and not variables().knowsPawn, "re-entering starts fresh" )

-- Space and clicks during the fade back to the menu neither end the passage nor start a trip.
do
	readPassage()
	local officeX, officeY = spotPoint( "office" )
	click( officeX, officeY )
	stub.sceneEvent( scene, "hide", "will" )
	local hourBefore = clock.hour
	local textBefore = player.bodyText.text
	press( "space" )
	press( "space" )
	local x, y = spotPoint( "bar" )
	click( x, y )
	check( not map.isOpen and player.bodyText.text == textBefore and clock.hour == hourBefore, "fade out blocks Space and map clicks" )
end

stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )
check( rawget( _G, "WEAVERx" .. settings.story.name ) == nil, "Weaver cache cleared on destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
