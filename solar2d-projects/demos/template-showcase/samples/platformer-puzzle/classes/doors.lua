-- Pressure switches and the doors they hold open: a door stays open while every one of its switches is held down.

local doors = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Body elements are numbered in the order addBody receives them.
local pressElement = 2
local holdElement = 3
local doorwayElement = 2

-- Only the solid part of a crate or the player presses a switch or fills a doorway, never the player's foot sensor.
local solidElement = 1

--------------------------------------------------------------------------------------
-- Private functions

-- Returns 1 when a crate or the player starts touching the given element, -1 when one stops, and 0 for anything else.
local function getContactChange( event, element )
	local kind = event.other.kind
	if event.selfElement ~= element or event.otherElement ~= solidElement or ( kind ~= "crate" and kind ~= "player" ) then
		return 0
	end

	return event.phase == "began" and 1 or -1
end

local function newImage( parent, path, width, height, spot )
	local image = display.newImageRect( parent, path, width, height )
	image.x, image.y = spot.x, spot.y

	return image
end

-- Turns an outline in art pixels into a shape in body coordinates, with the origin at the frame's centre.
local function newShape( outline, pixelSize, size )
	local shape = {}

	for i = 1, #outline do
		shape[i] = outline[i] * pixelSize - size * 0.5
	end

	return shape
end

local function newSensorBox( sensor )
	local halfHeight = ( sensor.bottom - sensor.top ) * 0.5

	return { halfWidth = sensor.halfWidth, halfHeight = halfHeight, x = 0, y = sensor.top + halfHeight }
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, map (from ponytiled), size (the tile size), images, config (settings.puzzle), tag and onSound.
-- The map's "switch" objects are named by letter, and each "door" object lists its switches' letters in its switches property.
function doors.new( params )
	local parent = params.parent
	local map = params.map
	local config = params.config
	local images = params.images
	local size = params.size

	local system = {}
	local switchesByName = {}
	local isStopped = false

	local function isHeld( door )
		for i = 1, #door.switches do
			if not door.switches[i].isPressed then
				return false
			end
		end

		return true
	end

	local function setOpen( door, isOpen )
		door.isOpen = isOpen
		door.isVisible = not isOpen
		door.isBodyActive = not isOpen
		door.openImage.isVisible = isOpen

		params.onSound( "door" )
	end

	-- Runs outside the collision handler, where bodies may change; a door only closes once nothing stands in its doorway.
	local function updateDoor( door )
		local shouldOpen = isHeld( door )

		if shouldOpen and not door.isOpen then
			setOpen( door, true )

		elseif not shouldOpen and door.isOpen and door.doorwayContacts == 0 then
			setOpen( door, false )
		end
	end

	local function scheduleDoor( door )
		local delay = isHeld( door ) and 1 or config.door.closeDelay

		timer.performWithDelay( delay, function()
			updateDoor( door )
		end, 1, params.tag )
	end

	local function setPressed( switch, isPressed )
		switch.isPressed = isPressed
		switch.isVisible = isPressed
		switch.upImage.isVisible = not isPressed

		if isPressed then
			params.onSound( "switch" )
		end

		-- The raised plate's body changes once the collisions are over, so whatever pressed it sinks onto the pressed plate.
		timer.performWithDelay( 1, function()
			switch.upImage.isBodyActive = not switch.isPressed
		end, 1, params.tag )

		for i = 1, #switch.doors do
			scheduleDoor( switch.doors[i] )
		end
	end

	-- Only the press sensor starts a press; the hold sensor keeps it while the crate or the player stays on the pressed plate.
	local function onSwitchCollision( event )
		local switch = event.target
		local pressChange = getContactChange( event, pressElement )
		local holdChange = getContactChange( event, holdElement )
		if isStopped or ( pressChange == 0 and holdChange == 0 ) then
			return
		end

		switch.pressContacts = switch.pressContacts + pressChange
		switch.holdContacts = switch.holdContacts + holdChange

		local isPressed = switch.pressContacts > 0 or ( switch.isPressed and switch.holdContacts > 0 )
		if isPressed ~= switch.isPressed then
			setPressed( switch, isPressed )
		end
	end

	local function onDoorwayCollision( event )
		local door = event.target.door
		local change = getContactChange( event, doorwayElement )
		if isStopped or change == 0 then
			return
		end

		door.doorwayContacts = door.doorwayContacts + change
		if door.doorwayContacts == 0 then
			scheduleDoor( door )
		end
	end

	-- The raised image carries the raised plate, active while the switch is up; the pressed image carries the pressed plate,
	-- which lies inside the raised one, and both sensors.
	local function addSwitches()
		local switchConfig = config.switch
		local raised = { shape = newShape( switchConfig.raisedOutline, switchConfig.pixelSize, size ), friction = switchConfig.friction, bounce = 0 }
		local pressed = { shape = newShape( switchConfig.pressedOutline, switchConfig.pixelSize, size ), friction = switchConfig.friction, bounce = 0 }
		local pressSensor = { box = newSensorBox( switchConfig.pressSensor ), isSensor = true }
		local holdSensor = { box = newSensorBox( switchConfig.holdSensor ), isSensor = true }

		local spots = map:listTypes( "switch" )

		for i = 1, #spots do
			local switch = newImage( parent, images.switchDown, size, size, spots[i] )
			switch.upImage = newImage( parent, images.switchUp, size, size, spots[i] )
			switch.isVisible = false
			switch.isGround = true
			switch.upImage.isGround = true
			switch.isPressed = false
			switch.pressContacts = 0
			switch.holdContacts = 0
			switch.doors = {}

			physics.addBody( switch.upImage, "static", raised )
			physics.addBody( switch, "static", pressed, pressSensor, holdSensor )
			switch:addEventListener( "collision", onSwitchCollision )

			local name = spots[i].name
			switchesByName[name] = switchesByName[name] or {}
			switchesByName[name][#switchesByName[name] + 1] = switch
		end
	end

	-- The closed image carries the gate's body; the open image carries the housing, which never opens, and the doorway sensor.
	local function addDoors()
		local doorConfig = config.door
		local gateHalf = doorConfig.gateHeight * 0.5
		local housingHalf = size - gateHalf

		local spots = map:listTypes( "door" )

		for i = 1, #spots do
			local door = newImage( parent, images.doorClosed, size, size * 2, spots[i] )
			door.isOpen = false
			door.doorwayContacts = 0
			door.switches = {}

			door.openImage = newImage( parent, images.doorOpen, size, size * 2, spots[i] )
			door.openImage.isVisible = false
			door.openImage.door = door

			-- The housing never opens, so the player can stand on it.
			door.openImage.isGround = true

			physics.addBody( door, "static", { box = { halfWidth = size * 0.5, halfHeight = gateHalf, x = 0, y = size - gateHalf }, bounce = 0 } )
			physics.addBody( door.openImage, "static",
				{ box = { halfWidth = size * 0.5, halfHeight = housingHalf, x = 0, y = housingHalf - size }, bounce = 0 },
				{ box = { halfWidth = doorConfig.doorwayWidth * 0.5, halfHeight = gateHalf, x = 0, y = size - gateHalf }, isSensor = true }
			)
			door.openImage:addEventListener( "collision", onDoorwayCollision )

			-- Idea: add levers that stay switched after one touch.
			for name in spots[i].switches:gmatch( "[^,]+" ) do
				local switches = switchesByName[name] or {}

				for switchIndex = 1, #switches do
					local switch = switches[switchIndex]
					door.switches[#door.switches + 1] = switch
					switch.doors[#switch.doors + 1] = door
				end
			end
		end
	end

	addSwitches()
	addDoors()

	-- Call before removing the room: bodies removed with it end their contacts, and those must not reach the doors.
	function system:stop()
		isStopped = true
	end

	return system
end

return doors
