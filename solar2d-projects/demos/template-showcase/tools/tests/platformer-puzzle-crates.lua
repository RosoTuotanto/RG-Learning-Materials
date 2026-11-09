-- Crates and switches under a Box2D-style contact solver: pushes onto a switch from either side, a crate left on a
-- pressed switch, how far a crate slides once nothing pushes it, and what counts as a press. Each scene is built from
-- the sample's own puzzle, doors and player classes and settings, on open floor with the switch at x 0.
-- Run from the demo root: lua5.1 tools/tests/platformer-puzzle-crates.lua
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
stub.install( harnessDirectory, ".scratch/tmp/platformer-puzzle-crates" )

local simulation = dofile( "tools/tests/support/platformer-puzzle-physics.lua" ).install( stub )
local physics = require( "physics" )

local settings = require( "samples.platformer-puzzle.data.settings" )
local puzzle = require( "samples.platformer-puzzle.classes.puzzle" )
local player = require( "samples.platformer-puzzle.classes.player" )

local tileSize = 36
local framesPerSecond = 60

-- A crate on the pressed plate has its bottom this far above the floor, and stays on the plate while its flat bottom
-- (the crate's width less both chamfers) overlaps the plate's top.
local pressedPlateHeight = 8
local plateReach = 10 + ( tileSize * 0.5 - settings.puzzle.crate.chamfer )

physics.start()
physics.setGravity( 0, settings.gravity )

local characterSheet = graphics.newImageSheet( settings.sheets.characters.path, {
	width = 48, height = 48, numFrames = 10, sheetContentWidth = 240, sheetContentHeight = 96,
} )

--------------------------------------------------------------------------------------
-- Scenes

local function newMap( objects )
	local map = {}

	function map:listTypes( kind )
		local found = {}
		for i = 1, #objects do
			if objects[i].type == kind then
				found[#found + 1] = objects[i]
			end
		end
		return found
	end

	function map:findObject( name )
		for i = 1, #objects do
			if objects[i].name == name then
				return objects[i]
			end
		end
		return false
	end

	return map
end

-- The floor's top is y 0; the switch frame is centred at x 0, and its door, the key and the exit stand far away.
-- params: crateX and crateY (or crates, a list of { x, y }), playerX and playerY (no playerX, no player),
-- wallSide (-1 or 1: a one-tile wall at that toe), blocks (a list of { x1, y1, x2, y2 } extra ground).
local function newScene( params )
	local scene = { direction = 0 }
	local group = display.newGroup()
	scene.group = group

	local function addGround( x1, y1, x2, y2 )
		local rect = display.newRect( group, ( x1 + x2 ) * 0.5, ( y1 + y2 ) * 0.5, x2 - x1, y2 - y1 )
		rect.isGround = true
		physics.addBody( rect, "static", { friction = 0.3, bounce = 0 } )
	end

	addGround( -800, 0, 800, tileSize )
	for i = 1, #( params.blocks or {} ) do
		addGround( unpack( params.blocks[i] ) )
	end
	if params.wallSide then
		local toe = params.wallSide * tileSize * 0.5
		addGround( math.min( toe, toe + params.wallSide * 200 ), -tileSize, math.max( toe, toe + params.wallSide * 200 ), 0 )
	end

	local objects = {
		{ type = "switch", name = "a", x = 0, y = -tileSize * 0.5 },
		{ type = "door", name = "A", switches = "a", x = 700, y = -tileSize },
		{ type = "key", name = "key", x = 650, y = -tileSize * 0.5 },
		{ type = "exit", name = "exit", x = -700, y = -tileSize },
	}
	local crates = params.crates or { { params.crateX, params.crateY or -tileSize * 0.5 } }
	for i = 1, #crates do
		objects[#objects + 1] = { type = "crate", name = "crate", x = crates[i][1], y = crates[i][2] }
	end
	local map = newMap( objects )

	scene.room = puzzle.new({
		parent = group, map = map, size = tileSize, images = settings.images, config = settings.puzzle, tag = "crates",
		onSound = function() end,
	})

	scene.crates = {}
	for i = 1, group.numChildren do
		local object = group[i]
		if object.kind == "crate" then
			scene.crate = object
			scene.crates[#scene.crates + 1] = object
		elseif object.upImage then
			scene.switch = object
		elseif object.doorwayContacts then
			scene.door = object
		end
	end

	if params.playerX then
		local controls = {}
		function controls:takePress() return false end
		function controls:isHeld() return false end
		function controls:getRunDirection() return scene.direction end

		scene.hero = player.new({
			parent = group, sheet = characterSheet, x = params.playerX, y = params.playerY or -24, input = controls, config = settings.player,
		})

		function scene.onEnterFrame()
			scene.hero:update()
		end
		Runtime:addEventListener( "enterFrame", scene.onEnterFrame )
	end

	function scene:destroy()
		if self.onEnterFrame then
			Runtime:removeEventListener( "enterFrame", self.onEnterFrame )
		end
		self.room:stop()
		timer.cancel( "crates" )
		transition.cancel( "crates" )
		display.remove( self.group )
	end

	return scene
end

local function isOnPlate( scene )
	local crate = scene.crate
	local bottomAboveFloor = -( crate.y + tileSize * 0.5 )

	return math.abs( crate.x ) < plateReach and math.abs( bottomAboveFloor - pressedPlateHeight ) < 1.5
end

local function isHeldDown( scene )
	return scene.switch.isPressed and scene.door.isOpen and not scene.switch.upImage.isBodyActive
end

--------------------------------------------------------------------------------------
-- Pushes onto the switch: from either side, crates starting at several distances from the switch's toe, and the player
-- standing against the crate or running into it. The player lets go as soon as the switch goes down.

local function crateStartX( side, gap )
	return side * ( tileSize + gap )
end

local runUps = { 0, 40, 150 }
local gaps = { 0, 30, 90 }

for side = -1, 1, 2 do
	for gapIndex = 1, #gaps do
		for runUpIndex = 1, #runUps do
			local gap, runUp = gaps[gapIndex], runUps[runUpIndex]
			local crateX = crateStartX( side, gap )
			local scene = newScene({ crateX = crateX, playerX = crateX + side * ( tileSize * 0.5 + 16 + 0.5 + runUp ) })
			local label = string.format( "pushed from the %s, crate %d from the toe, run-up %d", side > 0 and "right" or "left", gap, runUp )

			scene.direction = -side
			local frames = 0
			while not scene.switch.isPressed and frames < 6 * framesPerSecond do
				simulation.step()
				frames = frames + 1
			end
			scene.direction = 0

			check( scene.switch.isPressed, label .. ": the switch goes down" )

			simulation.steps( 2 * framesPerSecond )
			local vx = scene.crate:getLinearVelocity()
			check( isOnPlate( scene ) and isHeldDown( scene ) and math.abs( vx ) < 1,
				label .. ": the crate rests on the pressed plate and holds the door open, crate at " .. scene.crate.x .. ", " .. scene.crate.y )

			scene:destroy()
		end
	end
end

--------------------------------------------------------------------------------------
-- A crate left on a pressed switch: dropped onto the plate still sliding, as a push leaves it, then left alone for 10 s.

local dropOffsets = { 0, 8, -8 }
local dropSpeeds = { 3, 10 }

for offsetIndex = 1, #dropOffsets do
	for speedIndex = 1, #dropSpeeds do
		local offset, speed = dropOffsets[offsetIndex], dropSpeeds[speedIndex]
		local scene = newScene({ crateX = offset, crateY = -tileSize * 0.5 - 40 })
		scene.crate:setLinearVelocity( offset < 0 and -speed or speed, 0 )
		local label = string.format( "crate dropped at %d sliding %d", offset, speed )

		simulation.steps( framesPerSecond )
		local settledX = scene.crate.x
		local isAlwaysHeld = isHeldDown( scene )

		for _ = 1, 10 * framesPerSecond do
			simulation.step()
			isAlwaysHeld = isAlwaysHeld and isHeldDown( scene )
		end

		check( isAlwaysHeld and isOnPlate( scene ), label .. ": stays on the plate and holds the door open for 10 s" )
		check( math.abs( scene.crate.x - settledX ) < 0.5, label .. ": does not creep, moved " .. ( scene.crate.x - settledX ) )

		scene:destroy()
	end
end

--------------------------------------------------------------------------------------
-- Stopping once nothing pushes a crate: on the floor after a push, and on the pressed plate after landing at a run's speed.

do
	local scene = newScene({ crateX = 200, playerX = 200 - tileSize * 0.5 - 16.5 })
	scene.direction = 1
	simulation.steps( framesPerSecond )
	scene.direction = 0

	local releaseX = scene.crate.x
	simulation.steps( framesPerSecond )
	local vx = scene.crate:getLinearVelocity()
	check( scene.crate.x - releaseX < 4 and math.abs( vx ) < 1, "a crate pushed along the floor stops within 4 units, slid " .. ( scene.crate.x - releaseX ) )

	scene:destroy()
end

local landingSpeeds = { settings.player.pushSpeed, settings.player.runSpeed * 0.5 }

for i = 1, #landingSpeeds do
	local speed = landingSpeeds[i]
	local scene = newScene({ crateX = -6, crateY = -tileSize * 0.5 - 10 })
	scene.crate:setLinearVelocity( speed, 0 )

	simulation.steps( framesPerSecond )
	check( isOnPlate( scene ) and isHeldDown( scene ), "a crate landing on the plate at " .. speed .. " stops on it, crate at " .. scene.crate.x )

	scene:destroy()
end

--------------------------------------------------------------------------------------
-- What counts as a press: something on the plate's top, never a crate against a ramp; the player counts too.

do
	local scene = newScene({ crateX = tileSize + 0.2 })
	simulation.steps( framesPerSecond )
	check( not scene.switch.isPressed and scene.switch.upImage.isBodyActive, "a crate against the raised switch's ramp does not press it" )
	scene:destroy()

	scene = newScene({ crateX = 600, playerX = 0, playerY = -60 })
	simulation.steps( framesPerSecond )
	check( isHeldDown( scene ) and scene.hero.y > -24 - pressedPlateHeight - 1, "the player standing on the switch presses it and sinks with the plate" )
	scene:destroy()

	-- Centred 15.5 off the switch, the player's flat bottom just reaches the raised plate's top.
	for side = -1, 1, 2 do
		scene = newScene({ crateX = 600, playerX = side * 15.5, playerY = -60 })
		simulation.steps( framesPerSecond )
		check( isHeldDown( scene ), "the player standing on the raised plate's " .. ( side < 0 and "left" or "right" ) .. " edge presses it" )
		scene:destroy()
	end

	-- Pushed onto the plate against a wall, then off the other side: the switch comes back up and the door closes.
	scene = newScene({ crateX = crateStartX( 1, 20 ), playerX = crateStartX( 1, 20 ) + tileSize * 0.5 + 16.5, wallSide = -1 })
	scene.direction = -1
	simulation.steps( 3 * framesPerSecond )
	check( isOnPlate( scene ) and isHeldDown( scene ) and math.abs( scene.crate.x ) < 1,
		"a crate pushed against the wall beside the switch ends centred on the plate" )
	scene:destroy()

	scene = newScene({ crateX = -10, playerX = -10 - tileSize * 0.5 - 16.5 })
	simulation.steps( framesPerSecond )
	check( isHeldDown( scene ), "a crate set on the plate presses it" )
	scene.direction = 1
	simulation.steps( 2 * framesPerSecond )
	scene.direction = 0
	simulation.steps( framesPerSecond )
	check( scene.crate.x > plateReach + 10 and not scene.switch.isPressed and scene.switch.upImage.isBodyActive and not scene.door.isOpen,
		"a crate pushed off the plate releases the switch and the door closes" )
	scene:destroy()
end

--------------------------------------------------------------------------------------
-- Stacked crates against a one-tile block: the player pushes the bottom one, so neither moves and the top one stays put.

do
	local scene = newScene({
		crates = { { 200, -tileSize * 0.5 }, { 200, -tileSize * 1.5 } },
		playerX = 200 - tileSize * 0.5 - 16.5,
		blocks = { { 200 + tileSize * 0.5, -tileSize, 200 + tileSize * 1.5, 0 } },
	})
	simulation.steps( 10 )

	local bottom, top = scene.crates[1], scene.crates[2]
	if bottom.y < top.y then
		bottom, top = top, bottom
	end

	scene.direction = 1
	simulation.steps( framesPerSecond )
	scene.direction = 0
	simulation.steps( framesPerSecond )

	check( math.abs( bottom.x - 200 ) < 1, "the bottom crate of the stack stays against the block, at " .. bottom.x )
	check( math.abs( top.x - bottom.x ) < 2 and math.abs( bottom.y - top.y - tileSize ) < 1,
		"the top crate stays on the bottom one, " .. ( top.x - bottom.x ) .. " off" )

	scene:destroy()
end

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
