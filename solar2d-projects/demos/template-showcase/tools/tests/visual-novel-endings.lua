-- Play-through of every route in visual-novel-endings: everyone who speaks in the room is standing on stage.
-- Usage, from the demo root: lua5.1 tools/tests/visual-novel-endings.lua
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
stub.install( harnessDirectory, ".scratch/tmp/visual-novel-endings" )
stub.call( dofile, "main.lua" )

local prefix = "samples.visual-novel-endings."
local settings = require( prefix .. "data.settings" )

-- Capture the scene's player by wrapping the constructor before the scene requires it.
local player
local storyPlayer = require( prefix .. "classes.storyPlayer" )
local newPlayer = storyPlayer.new
storyPlayer.new = function( params ) player = newPlayer( params ) return player end

local _, scene = stub.call( require, prefix .. "demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

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

steps( 2 )

-- Speakers who stand in the room with the detective, by the character image they use.
local onStage = {
	["Jimmy"] = "jimmy",
	["Vivian Ash"] = "vivian",
	["Secretary"] = "secretary",
}

local layout = settings.player
local figureWidth = layout.characterWidth * layout.characterScale

local function has( text, part )
	return string.find( text, part, 1, true ) ~= nil
end

-- Checks one shown line: its speaker stands on stage, every figure has an image, and no two figures overlap.
local function checkLine( route, speaker, body )
	local label = route .. " \"" .. body .. "\""
	local name = onStage[speaker]

	if name then
		check( player.characters[name] ~= nil, label .. ": " .. speaker .. " speaks but is not shown" )
	end

	if speaker == "" and has( body, "Jimmy leaves" ) then
		check( player.characters.jimmy == nil, label .. ": Jimmy is still shown after he leaves" )
	end

	local shown = {}
	for characterName, character in pairs( player.characters ) do
		check( lfs.attributes( layout.characterFolder .. characterName .. ".png" ) ~= nil, label .. ": no image for " .. characterName )
		shown[#shown + 1] = character
	end

	for i = 1, #shown do
		for other = i + 1, #shown do
			check( math.abs( shown[i].x - shown[other].x ) >= figureWidth, label .. ": two figures overlap" )
		end
	end
end

-- Presses Space through the passage until it offers choices or ends, checking every line shown.
local function readPassage( route )
	local last

	for _ = 1, 40 do
		local speaker = player.speakerText.text
		local body = player.bodyText.text
		local line = speaker .. ": " .. body

		if line ~= last and player.isActive then
			checkLine( route, speaker, body )
			last = line
		end

		if #player.choices > 0 or not player.isActive then
			return
		end
		press( "space" )
	end
	check( false, route .. ": passage never ended" )
end

-- Plays from the opening, taking the numbered choice at each branch.
local function playRoute( route, picks )
	player:jumpTo( settings.story.firstPassage )
	readPassage( route )

	for i = 1, #picks do
		player:choose( picks[i] )
		readPassage( route )
	end
	check( not player.isActive, route .. ": route did not reach an ending" )
end

-- The opening, with Jimmy at the door.
do
	player:jumpTo( settings.story.firstPassage )
	local sawJimmy = false

	for _ = 1, 40 do
		if player.speakerText.text == "Jimmy" then
			sawJimmy = true
			check( player.characters.jimmy ~= nil, "opening: Jimmy speaks in the office but is not shown" )
		end
		if #player.choices > 0 then
			break
		end
		press( "space" )
	end
	check( sawJimmy, "opening: Jimmy speaks" )
end

playRoute( "hear him out, pawn ticket", { 1, 2 } )
playRoute( "throw him out, go after Jimmy, paid in full", { 2, 2, 1 } )
playRoute( "throw him out, closed by nine", { 2, 1 } )

-- Jimmy stands in the office while the detective throws him out, before he has a line.
player:jumpTo( "ThrowHimOut" )
check( player.characters.jimmy ~= nil and has( player.bodyText.text, "Out." ), "Jimmy is shown while he is thrown out" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
