local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

local movement = require( "samples.platformer-precision.classes.movement" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Body elements are numbered in the order addBody receives them.
local footElement = 2
local leftElement = 3
local rightElement = 4

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, sheet, x, y, input, config (settings.player) and an optional onMove function that gets each movement event.
function player.new( params )
	local config = params.config
	local controls = params.input
	local body = config.body

	local hero = display.newSprite( params.parent, params.sheet, config.sequence )
	hero.x, hero.y = params.x, params.y
	hero.xScale = config.startDirection * config.artFacing

	local halfWidth = body.width * 0.5
	local top = body.offsetY - body.height * 0.5
	local bottom = body.offsetY + body.height * 0.5
	local chamfer = body.chamfer

	-- Cut corners let the body slide past tile edges instead of catching on them.
	local shape = {
		-halfWidth + chamfer, top,
		halfWidth - chamfer, top,
		halfWidth, top + chamfer,
		halfWidth, bottom - chamfer,
		halfWidth - chamfer, bottom,
		-halfWidth + chamfer, bottom,
		-halfWidth, bottom - chamfer,
		-halfWidth, top + chamfer,
	}

	-- No friction, so pressing into a wall in the air never holds the player up.
	local solidPart = { shape = shape, density = config.density, friction = 0, bounce = 0 }

	-- The foot sensor is narrower than the body, so touching a wall never counts as standing on ground.
	local foot = {
		box = { halfWidth = config.foot.width * 0.5, halfHeight = config.foot.height * 0.5, x = 0, y = bottom },
		isSensor = true,
	}

	local function newWallSensor( side )
		local size = config.wallSensor

		return {
			box = { halfWidth = size.width * 0.5, halfHeight = size.height * 0.5, x = side * halfWidth, y = body.offsetY },
			isSensor = true,
		}
	end

	physics.addBody( hero, "dynamic", solidPart, foot, newWallSensor( -1 ), newWallSensor( 1 ) )
	hero.isFixedRotation = true

	local mover = movement.new( config )

	-- Contact counts per element, because one sensor can touch several ground bodies at once.
	local contacts = { [footElement] = 0, [leftElement] = 0, [rightElement] = 0 }

	local frame = {}

	local function onSensorCollision( event )
		local count = contacts[event.selfElement]
		if not count or not event.other.isGround then
			return
		end

		if event.phase == "began" then
			contacts[event.selfElement] = count + 1

		elseif event.phase == "ended" then
			contacts[event.selfElement] = count - 1
		end
	end

	hero:addEventListener( "collision", onSensorCollision )

	local function getWallSide()
		if contacts[rightElement] > 0 then
			return 1

		elseif contacts[leftElement] > 0 then
			return -1
		end

		return 0
	end

	function hero:update( now )
		local vx, vy = self:getLinearVelocity()

		frame.now = now
		frame.isGrounded = contacts[footElement] > 0
		frame.wallSide = getWallSide()
		frame.runDirection = controls:getRunDirection()
		frame.aimY = ( controls:isHeld( "down" ) and 1 or 0 ) - ( controls:isHeld( "up" ) and 1 or 0 )
		frame.isJumpHeld = controls:isHeld( "jump" )
		frame.isJumpPressed = controls:takePress( "jump" )
		frame.isDashPressed = controls:takePress( "dash" )
		frame.vx, frame.vy = vx, vy

		local result = mover:update( frame )

		self.gravityScale = result.gravityScale
		self:setLinearVelocity( result.vx, result.vy )

		if result.impulseX ~= 0 or result.impulseY ~= 0 then
			self:applyLinearImpulse( result.impulseX, result.impulseY, self.x, self.y )
		end

		self.xScale = result.facing * config.artFacing

		if frame.runDirection ~= 0 then
			if not self.isPlaying then
				self:play()
			end

		else
			self:pause()
			self:setFrame( 1 )
		end

		if result.event and params.onMove then
			params.onMove( result.event )
		end
	end

	-- Moves the player to x, y at rest with every jump, dash and timer cleared.
	function hero:respawn( x, y )
		mover:reset()

		self.x, self.y = x, y
		self.gravityScale = 1
		self:setLinearVelocity( 0, 0 )
		self.xScale = config.startDirection * config.artFacing
	end

	-- Stops running and any dash, so the player only falls with gravity.
	function hero:stop()
		local _, vy = self:getLinearVelocity()
		self:setLinearVelocity( 0, vy )
		self.gravityScale = 1
		self:pause()

		mover:reset()
	end

	return hero
end

return player
