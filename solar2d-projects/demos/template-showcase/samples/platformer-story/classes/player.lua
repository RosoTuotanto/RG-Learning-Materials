local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Body elements are numbered in the order addBody receives them.
local footElement = 2

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, sheet, x, y, input and config (settings.player).
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

	physics.addBody( hero, "dynamic", solidPart, foot )
	hero.isFixedRotation = true

	local groundContacts = 0
	local isJumping = false

	local function onFootCollision( event )
		if event.selfElement ~= footElement or not event.other.isGround then
			return
		end

		if event.phase == "began" then
			groundContacts = groundContacts + 1

		elseif event.phase == "ended" then
			groundContacts = groundContacts - 1
		end
	end

	hero:addEventListener( "collision", onFootCollision )

	function hero:isGrounded()
		return groundContacts > 0
	end

	function hero:update()
		local direction = controls:getRunDirection()
		local _, vy = self:getLinearVelocity()

		local vx = direction * config.runSpeed
		self:setLinearVelocity( vx, vy )

		if direction ~= 0 then
			self.xScale = direction * config.artFacing
			if not self.isPlaying then
				self:play()
			end

		else
			self:pause()
			self:setFrame( 1 )
		end

		if controls:takePress( "jump" ) and self:isGrounded() then
			self:setLinearVelocity( vx, 0 )
			self:applyLinearImpulse( 0, -config.jumpImpulse, self.x, self.y )
			isJumping = true

		elseif isJumping and ( vy >= 0 or not controls:isHeld( "jump" ) ) then
			-- Letting go of jump while still rising cuts the jump short.
			if vy < 0 then
				self:setLinearVelocity( vx, vy * config.jumpCut )
			end

			isJumping = false
		end
	end

	-- Stops running, so the player only falls with gravity.
	function hero:stop()
		local _, vy = self:getLinearVelocity()
		self:setLinearVelocity( 0, vy )
		self:pause()
		self:setFrame( 1 )
		isJumping = false
	end

	-- Puts the player back on its feet at x, y after a fall.
	function hero:respawn( x, y )
		self.x, self.y = x, y
		self:setLinearVelocity( 0, 0 )
		self:stop()
	end

	return hero
end

return player
