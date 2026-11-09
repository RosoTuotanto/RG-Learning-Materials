-- Plays one crop from tilling to harvest through the real scene in the harness stub, sleeping in the bed twice.
local harnessDirectory = "tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local temporaryRoot = ".scratch/tmp/top-down-farming-play"
local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

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
	frames( 2 )
end

local function find( group, test )
	if test( group ) then
		return group
	end

	for i = 1, ( group.numChildren or 0 ) do
		local found = find( group[i], test )
		if found then
			return found
		end
	end
end

local function expectText( text, label )
	if not find( sceneView, function( object ) return object.text == text end ) then
		failures = failures + 1
		print( "FAIL " .. label .. ": no '" .. text .. "'" )
	end
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.top-down-farming.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
sceneView = scene.view

local hero = find( sceneView, function( object ) return object.getTargetTile ~= nil end )

-- Tile centres are ( column - 0.5 ) * 32 in the world group.
local function standAt( column, row, facingX, facingY )
	hero.x, hero.y = ( column - 0.5 ) * 32, ( row - 0.5 ) * 32
	hero.facingX, hero.facingY = facingX, facingY
	frames( 1 )
end

local function useOnField( toolKey )
	standAt( 12, 5, 1, 0 )
	tap( toolKey )
	tap( "space" )
end

local function sleepInBed()
	standAt( 5, 5, -1, 0 )
	tap( "e" )
	frames( 120 )
end

expectText( "Day 1", "start" )

useOnField( "4" )
expectText( "Harvested: 0", "hand on grass" )

useOnField( "1" )
useOnField( "2" )
useOnField( "3" )
sleepInBed()
expectText( "Day 2", "first sleep" )

useOnField( "4" )
expectText( "Harvested: 0", "hand on an unripe crop" )

useOnField( "3" )
sleepInBed()
expectText( "Day 3", "second sleep" )

useOnField( "4" )
expectText( "Harvested: 1", "harvest on day 3" )

-- A slot touch during the sleep fade must leave the hand (slot 4) selected; the selected border is thicker.
local function slotNamed( number )
	return find( sceneView, function( object ) return object.text == number end ).parent
end

local seedsSlot = slotNamed( "2" )
standAt( 5, 5, -1, 0 )
tap( "space" )
frames( 10 )
stub.touchObject( seedsSlot, seedsSlot.x, seedsSlot.y, "began" )
stub.touchObject( seedsSlot, seedsSlot.x, seedsSlot.y, "ended" )
frames( 120 )

if seedsSlot[1].strokeWidth ~= 2 or slotNamed( "4" )[1].strokeWidth ~= 3 then
	failures = failures + 1
	print( "FAIL touch during sleep changed the tool" )
end

stub.touchObject( seedsSlot, seedsSlot.x, seedsSlot.y, "began" )
stub.touchObject( seedsSlot, seedsSlot.x, seedsSlot.y, "ended" )
if seedsSlot[1].strokeWidth ~= 3 then
	failures = failures + 1
	print( "FAIL touch while awake did not select the tool" )
end

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )

os.execute( "rm -rf '" .. temporaryRoot .. "'" )
print( failures == 0 and "play-through OK" or ( failures .. " failures" ) )
