local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Localised functions

local abs = math.abs

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Body elements are numbered in the order addBody receives them.
local solidElement = 1
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
	hero.kind = "player"

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

	-- Crates touching the solid body, each with its count of touching element pairs.
	local touchingCrates = {}

	local function onCollision( event )
		local other = event.other
		local change = event.phase == "began" and 1 or -1

		if event.selfElement == footElement and other.isGround then
			groundContacts = groundContacts + change

		elseif event.selfElement == solidElement and other.kind == "crate" then
			local count = ( touchingCrates[other] or 0 ) + change
			touchingCrates[other] = count > 0 and count or nil
		end
	end

	hero:addEventListener( "collision", onCollision )

	-- A crate beside the player in the running direction is being pushed, the lowest one when crates are stacked;
	-- one underneath is being stood on.
	local function findPushedCrate( direction )
		local pushed, pushedOffset = nil, config.pushReach

		for crate in pairs( touchingCrates ) do
			local offset = abs( crate.y - hero.y )

			if ( crate.x - hero.x ) * direction > 0 and offset < pushedOffset then
				pushed, pushedOffset = crate, offset
			end
		end

		return pushed
	end

	function hero:update()
		local wantsJump = controls:takePress( "jump" )
		local direction = controls:getRunDirection()
		local _, vy = self:getLinearVelocity()

		local crate = findPushedCrate( direction )
		local vx = direction * ( crate and config.pushSpeed or config.runSpeed )
		self:setLinearVelocity( vx, vy )

		-- The player sets the pushed crate's speed itself: pushed by contact alone, a crate this heavy stalls on a switch's ramp.
		if crate then
			local _, crateVy = crate:getLinearVelocity()
			crate:setLinearVelocity( vx, crateVy )
		end

		if direction ~= 0 then
			self.xScale = direction * config.artFacing
			if not self.isPlaying then
				self:play()
			end

		else
			self:pause()
			self:setFrame( 1 )
		end

		if wantsJump and groundContacts > 0 then
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
	end

	return hero
end

return player
