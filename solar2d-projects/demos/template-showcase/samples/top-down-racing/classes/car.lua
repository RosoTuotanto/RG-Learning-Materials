-- A Box2D top-down car: engine force along its heading, sideways grip from an impulse, and speed-scaled steering.

local car = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Localised functions

local abs = math.abs
local cos = math.cos
local min = math.min
local rad = math.rad
local sin = math.sin

--------------------------------------------------------------------------------------
-- Public functions

-- Returns the impulse that removes the grip share (0 to 1) of the velocity across the heading.
-- Solar2D passes impulses to Box2D unscaled, so a change in content units per second is divided by pixelsPerMeter.
function car.getGripImpulse( velocityX, velocityY, rotation, grip, mass, pixelsPerMeter )
	local angle = rad( rotation )
	local rightX, rightY = -sin( angle ), cos( angle )

	local sidewaysSpeed = velocityX * rightX + velocityY * rightY
	local impulse = -sidewaysSpeed * grip * mass / pixelsPerMeter

	return rightX * impulse, rightY * impulse
end

-- params: parent, x, y, controls (classes/input.lua), config (settings.car) and pixelsPerMeter.
function car.new( params )
	local config = params.config
	local controls = params.controls
	local pixelsPerMeter = params.pixelsPerMeter

	local racer = display.newImageRect( params.parent, config.image, config.width, config.height )
	racer.x, racer.y = params.x, params.y

	physics.addBody( racer, "dynamic", {
		density = config.body.density,
		friction = config.body.friction,
		bounce = config.body.bounce,
		box = { halfWidth = config.bodyWidth * 0.5, halfHeight = config.bodyHeight * 0.5 },
	})
	racer.isSleepingAllowed = false
	racer.linearDamping = config.trackDamping

	-- Runs every frame; the car is drawn facing +x, so rotation 0 drives right.
	function racer:drive( isOnTrack )
		local angle = rad( self.rotation )
		local forwardX, forwardY = cos( angle ), sin( angle )

		local velocityX, velocityY = self:getLinearVelocity()
		local forwardSpeed = velocityX * forwardX + velocityY * forwardY

		-- Down brakes while the car still rolls forward and reverses slowly once it has nearly stopped.
		local acceleration = 0
		if controls:isHeld( "accelerate" ) and forwardSpeed < config.maxSpeed then
			acceleration = config.acceleration

		elseif controls:isHeld( "brake" ) then
			if forwardSpeed > config.reverseBelowSpeed then
				acceleration = -config.braking

			elseif forwardSpeed > -config.maxReverseSpeed then
				acceleration = -config.reverseAcceleration
			end
		end

		-- Forces are Box2D units too, so the acceleration is converted the same way as the grip impulse.
		local force = self.mass * acceleration / pixelsPerMeter
		self:applyForce( forwardX * force, forwardY * force, self.x, self.y )

		local grip = controls:isHeld( "handbrake" ) and config.driftGrip or config.grip
		local impulseX, impulseY = car.getGripImpulse( velocityX, velocityY, self.rotation, grip, self.mass, pixelsPerMeter )
		self:applyLinearImpulse( impulseX, impulseY, self.x, self.y )

		-- A car only turns while it rolls, and turns the other way while reversing.
		local turnScale = min( abs( forwardSpeed ) / config.fullTurnSpeed, 1 )
		if forwardSpeed < 0 then
			turnScale = -turnScale
		end
		self.angularVelocity = controls:getAxis( "left", "right" ) * config.turnRate * turnScale

		self.linearDamping = isOnTrack and config.trackDamping or config.grassDamping
	end

	-- Returns the car's speed into the face of the wall tile it touches, found on grid (classes/mapGrid.lua); a face shared
	-- with a solid neighbour cannot be hit, so sliding along a row of trees never counts each new tile as a crash.
	function racer:getSpeedInto( wall, grid )
		local velocityX, velocityY = self:getLinearVelocity()

		local column, row = grid:getNearestWallTile( wall, self.x, self.y )
		local tileX, tileY = grid:tileToWorld( column, row )

		local offsetX, offsetY = self.x - tileX, self.y - tileY
		local stepX = offsetX < 0 and -1 or 1
		local stepY = offsetY < 0 and -1 or 1

		local isOpenX = not grid:isSolid( column + stepX, row )
		local isOpenY = not grid:isSolid( column, row + stepY )

		-- Of the open faces, the hit one is where the car's bounding box overlaps the tile least.
		local angle = rad( self.rotation )
		local halfX = ( abs( cos( angle ) ) * config.bodyWidth + abs( sin( angle ) ) * config.bodyHeight ) * 0.5
		local halfY = ( abs( sin( angle ) ) * config.bodyWidth + abs( cos( angle ) ) * config.bodyHeight ) * 0.5
		local overlapX = halfX + grid.tileSize * 0.5 - abs( offsetX )
		local overlapY = halfY + grid.tileSize * 0.5 - abs( offsetY )

		if isOpenX and ( not isOpenY or overlapX < overlapY ) then
			return -velocityX * stepX

		elseif isOpenY then
			return -velocityY * stepY
		end

		return 0
	end

	return racer
end

return car
