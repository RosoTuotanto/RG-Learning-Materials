-- Plays the sample scene through all three rooms with key events in the harness stub, then presses Play again.
local harnessDirectory = "tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local temporaryRoot = ".scratch/tmp/top-down-puzzle-play"
local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

local keyForMove = { U = "up", D = "down", L = "left", R = "right" }
local solutions = {
	"UURRRUURU",
	"URUURRRRRULULDDLLUUU",
	"RURURRRRRUULDDUUULLDLLDLLUURDLDDRRUURURU",
}

local failures = 0
local sceneView

local function frames( count )
	for _ = 1, count do
		stub.step()
	end
end

local function tap( keyName )
	stub.key( keyName, "down", false )
	stub.key( keyName, "up", false )
	frames( 12 )
end

-- Collects every visible text string under a group.
local function visibleTexts( group, found )
	found = found or {}
	if not group.isVisible then
		return found
	end

	if group.text then
		found[group.text] = true
	end

	for i = 1, ( group.numChildren or 0 ) do
		visibleTexts( group[i], found )
	end

	return found
end

local function expect( text, label )
	if not visibleTexts( sceneView )[text] then
		failures = failures + 1
		print( "FAIL " .. label .. ": no visible '" .. text .. "'" )
	end
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.top-down-puzzle.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
sceneView = scene.view

expect( "Room 1 / 3", "start" )
tap( "right" )
tap( "z" )
expect( "Moves: 0", "undo after a step" )
tap( "up" )
tap( "r" )
expect( "Moves: 0", "restart" )

for index = 1, #solutions do
	expect( "Room " .. index .. " / 3", "room " .. index .. " shown" )
	for i = 1, #solutions[index] - 1 do
		tap( keyForMove[solutions[index]:sub( i, i )] )
	end
	expect( "Moves: " .. ( #solutions[index] - 1 ), "room " .. index .. " move count" )
	tap( keyForMove[solutions[index]:sub( -1 )] )
end

expect( "All rooms solved", "finished screen" )

local touchables = stub.touchables( scene.view )
for i = 1, #touchables do
	local bounds = stub.contentBounds( touchables[i] )
	local x = ( bounds.xMin + bounds.xMax ) * 0.5
	local y = ( bounds.yMin + bounds.yMax ) * 0.5
	stub.touchObject( touchables[i], x, y, "began" )
end
frames( 2 )
expect( "Room 1 / 3", "play again" )

-- Holding a key keeps stepping: 40 frames of right from the room 1 start walk several tiles.
stub.key( "right", "down", false )
frames( 40 )
stub.key( "right", "up", false )
frames( 12 )
expect( "Moves: 4", "held key repeats" )

local function expectNone( text, label )
	if visibleTexts( sceneView )[text] then
		failures = failures + 1
		print( "FAIL " .. label .. ": '" .. text .. "' is visible" )
	end
end

-- Hiding mid-step into the open door must not change rooms during the fade.
tap( "r" )
for i = 1, #solutions[1] - 1 do
	tap( keyForMove[solutions[1]:sub( i, i )] )
end
stub.key( "up", "down", false )
frames( 2 )
stub.key( "up", "up", false )
stub.sceneEvent( scene, "hide", "will" )
frames( 30 )
expect( "Room 1 / 3", "hide mid-step into the door keeps room 1" )
expectNone( "Room 2 / 3", "hide mid-step into the door" )
stub.sceneEvent( scene, "hide", "did" )
frames( 5 )
expect( "Room 1 / 3", "still room 1 after hide did" )

stub.sceneEvent( scene, "destroy" )

for message in pairs( stub.errorsByMessage ) do
	failures = failures + 1
	print( "ERROR " .. tostring( message ) )
end

print( "play-through: " .. failures .. " failures" )
