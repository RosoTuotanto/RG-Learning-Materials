-- Builds a room's crates, switches and doors, key and exit.

local puzzle = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

local doors = require( "samples.platformer-puzzle.classes.doors" )

--------------------------------------------------------------------------------------
-- Private functions

local function newChamferedBox( size, chamfer )
	local half = size * 0.5

	return {
		-half + chamfer, -half,
		half - chamfer, -half,
		half, -half + chamfer,
		half, half - chamfer,
		half - chamfer, half,
		-half + chamfer, half,
		-half, half - chamfer,
		-half, -half + chamfer,
	}
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, map (from ponytiled), size (the tile size), images, config (settings.puzzle), tag and onSound.
-- The map's "game" layer holds crate, key and exit points, and the switches and doors doors.new reads.
function puzzle.new( params )
	local parent = params.parent
	local map = params.map
	local config = params.config
	local images = params.images
	local size = params.size

	local room = { hasKey = false }

	local doorSystem = doors.new( params )

	local exitSpot = map:findObject( "exit" )
	local exitDoor = display.newImageRect( parent, images.exitDoor, size, size * 2 )
	exitDoor.x, exitDoor.y = exitSpot.x, exitSpot.y
	exitDoor.kind = "exit"
	physics.addBody( exitDoor, "static", { isSensor = true } )

	local exitOpen = display.newImageRect( parent, images.exitDoorOpen, size, size * 2 )
	exitOpen.x, exitOpen.y = exitSpot.x, exitSpot.y
	exitOpen.isVisible = false

	local keyConfig = config.key
	local keySpot = map:findObject( "key" )
	local key = display.newImageRect( parent, images.key, size, size )
	key.x, key.y = keySpot.x, keySpot.y
	key.kind = "key"
	physics.addBody( key, "static", { box = { halfWidth = keyConfig.sensorWidth * 0.5, halfHeight = keyConfig.sensorHeight * 0.5 }, isSensor = true } )

	transition.to( key, {
		y = key.y - keyConfig.bobHeight,
		time = keyConfig.bobTime,
		iterations = -1,
		transition = easing.continuousLoop,
		tag = params.tag,
	} )

	-- Idea: make crates float in water, so a crate pushed into a pool becomes a raft.
	local crateConfig = config.crate
	local crateShape = newChamferedBox( size, crateConfig.chamfer )
	local crateSpots = map:listTypes( "crate" )

	for i = 1, #crateSpots do
		local crate = display.newImageRect( parent, images.crate, size, size )
		crate.x, crate.y = crateSpots[i].x, crateSpots[i].y
		crate.kind = "crate"
		crate.isGround = true

		physics.addBody( crate, "dynamic", { shape = crateShape, density = crateConfig.density, friction = crateConfig.friction, bounce = 0 } )
		crate.isFixedRotation = true
	end

	-- Safe inside a collision handler: the key's body is removed a frame later.
	function room:takeKey( carrier )
		if self.hasKey then
			return
		end

		self.hasKey = true
		self.carrier = carrier

		transition.cancel( key )
		key:toFront()
		params.onSound( "key" )

		timer.performWithDelay( 1, function()
			physics.removeBody( key )
		end, 1, params.tag )
	end

	function room:openExit()
		exitDoor.isVisible = false
		exitOpen.isVisible = true
		key.isVisible = false

		params.onSound( "door" )
	end

	-- A carried key rides above the carrier's head.
	function room:update()
		if self.hasKey then
			key.x = self.carrier.x
			key.y = self.carrier.y + keyConfig.carriedOffsetY
		end
	end

	-- Call before removing the room.
	function room:stop()
		doorSystem:stop()
	end

	return room
end

return puzzle
