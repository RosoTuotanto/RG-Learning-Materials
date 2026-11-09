local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Localised functions

local getTimer = system.getTimer

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Body elements are numbered in the order addBody receives them.
local footElement = 2

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, sheet, x, y, input, filter and config (settings.player).
function player.new( params )
	local config = params.config
	local controls = params.input
	local body = config.body

	local hero = display.newSprite( params.parent, params.sheet, config.sequence )
	hero.x, hero.y = params.x, params.y

	-- 1 right, -1 left; the gun holds to this side whichever way it aims.
	hero.facing = config.startDirection
	hero.xScale = hero.facing * config.artFacing

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
	local solidPart = { shape = shape, density = config.density, friction = 0, bounce = 0, filter = params.filter }

	-- The foot sensor is narrower than the body, so touching a wall never counts as standing on ground.
	local foot = {
		box = { halfWidth = config.foot.width * 0.5, halfHeight = config.foot.height * 0.5, x = 0, y = bottom },
		isSensor = true,
		filter = params.filter,
	}

	physics.addBody( hero, "dynamic", solidPart, foot )
	hero.isFixedRotation = true

	hero.hp = config.hp

	local groundContacts = 0
	local isJumping = false
	local flashUntil = 0
	local controlLockedUntil = 0

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

	local function launch( impulse )
		local vx = hero:getLinearVelocity()
		hero:setLinearVelocity( vx, 0 )
		hero:applyLinearImpulse( 0, -impulse, hero.x, hero.y )
	end

	function hero:isGrounded()
		return groundContacts > 0
	end

	function hero:update()
		local now = getTimer()

		if now < flashUntil then
			self:setFillColor( unpack( config.flashColor ) )
		else
			self:setFillColor( 1 )
		end

		local wantsJump = controls:takePress( "jump" )

		-- A knockback carries the player for a moment before the keys take over again.
		if now < controlLockedUntil then
			return
		end

		local direction = controls:getRunDirection()
		local _, vy = self:getLinearVelocity()

		local vx = direction * config.runSpeed
		self:setLinearVelocity( vx, vy )

		-- Idea: switch between idle, run and jump animations from a sprite sheet here.
		if direction ~= 0 then
			self.facing = direction
			self.xScale = direction * config.artFacing

			if not self.isPlaying then
				self:play()
			end

		else
			self:pause()
			self:setFrame( 1 )
		end

		if wantsJump and self:isGrounded() then
			launch( config.jumpImpulse )
			isJumping = true

		elseif isJumping and ( vy >= 0 or not controls:isHeld( "jump" ) ) then
			-- Letting go of jump while still rising cuts the jump short.
			if vy < 0 then
				self:setLinearVelocity( vx, vy * config.jumpCut )
			end

			isJumping = false
		end
	end

	-- Takes damage, flashes and knocks the player away from fromX.
	function hero:hurt( damage, fromX )
		local now = getTimer()

		self.hp = self.hp - damage
		flashUntil = now + config.flashTime
		controlLockedUntil = now + config.knockback.time
		isJumping = false

		local away = self.x < fromX and -1 or 1
		self:setLinearVelocity( away * config.knockback.speed, -config.knockback.rise )
	end

	-- Stops running, so the player only falls with gravity.
	function hero:stop()
		local _, vy = self:getLinearVelocity()
		self:setLinearVelocity( 0, vy )
		self:pause()
		self:setFillColor( 1 )
	end

	return hero
end

return player
