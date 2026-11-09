-- The player's timing rules, kept free of display objects and physics so they read in one place.

local movement = {}

--------------------------------------------------------------------------------------
-- Localised functions

local sqrt = math.sqrt

--------------------------------------------------------------------------------------
-- Public functions

-- config is settings.player. update takes the frame's state and returns the velocity, impulse and gravity to apply.
function movement.new( config )
	local mover = {}

	local result = { vx = 0, vy = 0, impulseX = 0, impulseY = 0, gravityScale = 1, facing = 1, event = nil }

	local facing
	local lastGroundedAt
	local jumpPressedAt
	local isJumping
	local controlLockedUntil
	local isDashing
	local dashEndsAt
	local dashX, dashY
	local hasDash

	function mover:reset()
		facing = config.startDirection
		lastGroundedAt = -math.huge
		jumpPressedAt = -math.huge
		isJumping = false
		controlLockedUntil = -math.huge
		isDashing = false
		dashEndsAt = 0
		dashX, dashY = 0, 0
		hasDash = true
	end

	-- Aims at the held direction, or straight ahead when nothing is held; a sideways dash turns the player its way.
	local function startDash( now, aimX, aimY )
		if aimX == 0 and aimY == 0 then
			aimX = facing

		elseif aimX ~= 0 then
			facing = aimX
		end

		local length = sqrt( aimX * aimX + aimY * aimY )
		dashX, dashY = aimX / length, aimY / length

		isDashing = true
		hasDash = false
		isJumping = false
		dashEndsAt = now + config.dash.time
	end

	-- frame: now (milliseconds), isGrounded, wallSide (-1, 0 or 1), runDirection, aimY, isJumpHeld, isJumpPressed, isDashPressed, vx and vy.
	function mover:update( frame )
		local now = frame.now
		local wallSide = frame.wallSide
		local vx, vy = frame.vx, frame.vy

		result.impulseX, result.impulseY = 0, 0
		result.event = nil

		-- The foot sensor still touches the ground for a frame after a jump, which must not count as landing.
		local isOnGround = frame.isGrounded and not isJumping
		if isOnGround then
			lastGroundedAt = now
		end

		if frame.isJumpPressed then
			jumpPressedAt = now
		end

		if isDashing and now >= dashEndsAt then
			isDashing = false
			vx = dashX * config.dash.speed * config.dash.endFactor
			vy = dashY * config.dash.speed * config.dash.endFactor

			-- The keys wait a moment, so the carried sideways speed is not replaced on the same frame.
			controlLockedUntil = now + config.dash.carryTime
		end

		if not isDashing and ( isOnGround or wallSide ~= 0 ) then
			hasDash = true
		end

		if frame.isDashPressed and hasDash and not isDashing then
			startDash( now, frame.runDirection, frame.aimY )
			result.event = "dash"
		end

		if isDashing then
			result.vx = dashX * config.dash.speed
			result.vy = dashY * config.dash.speed
			result.gravityScale = 0
			result.facing = facing

			return result
		end

		local wantsJump = now - jumpPressedAt <= config.jumpBufferTime

		if wantsJump and now - lastGroundedAt <= config.coyoteTime then
			vy = 0
			result.impulseY = -config.jumpImpulse
			result.event = "jump"

			isJumping = true
			lastGroundedAt = -math.huge
			jumpPressedAt = -math.huge

		elseif wantsJump and wallSide ~= 0 then
			vx, vy = 0, 0
			result.impulseX = -wallSide * config.wallJump.impulseX
			result.impulseY = -config.wallJump.impulseY
			result.event = "jump"

			facing = -wallSide
			isJumping = true
			jumpPressedAt = -math.huge
			controlLockedUntil = now + config.wallJump.lockTime

		elseif isJumping and ( vy >= 0 or not frame.isJumpHeld ) then
			-- Letting go of jump while still rising cuts the jump short.
			if vy < 0 then
				vy = vy * config.jumpCut
			end

			isJumping = false
		end

		-- Right after a wall jump the keys cannot steer, so pressing into the wall does not undo the push.
		if now >= controlLockedUntil then
			vx = frame.runDirection * config.runSpeed

			if frame.runDirection ~= 0 then
				facing = frame.runDirection
			end
		end

		if not isOnGround and wallSide ~= 0 and frame.runDirection == wallSide and vy > config.wallSlideSpeed then
			vy = config.wallSlideSpeed
		end

		result.vx, result.vy = vx, vy
		result.gravityScale = 1
		result.facing = facing

		return result
	end

	mover:reset()

	return mover
end

return movement
