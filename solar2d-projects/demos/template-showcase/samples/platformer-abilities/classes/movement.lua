-- The player's timing rules, kept free of display objects and physics so they read in one place.

local movement = {}

--------------------------------------------------------------------------------------
-- Public functions

-- config is settings.player. update takes the frame's state and returns the velocity, impulse and gravity to apply.
function movement.new( config )
	local mover = {
		-- Abilities stay owned through respawns; only a new mover starts without them.
		-- Idea: add more abilities, such as a wall jump or swimming, each behind its own flag here.
		abilities = { doubleJump = false, dash = false },
	}

	local result = { vx = 0, vy = 0, impulseY = 0, gravityScale = 1, facing = 1, event = nil }

	local facing
	local lastGroundedAt
	local jumpPressedAt
	local isJumping
	local controlLockedUntil
	local isDashing
	local dashEndsAt
	local hasDash
	local hasAirJump

	function mover:reset()
		facing = config.startDirection
		lastGroundedAt = -math.huge
		jumpPressedAt = -math.huge
		isJumping = false
		controlLockedUntil = -math.huge
		isDashing = false
		dashEndsAt = 0
		hasDash = true
		hasAirJump = true
	end

	-- frame: now (milliseconds), isGrounded, runDirection, isJumpHeld, isJumpPressed, isDashPressed, vx and vy.
	function mover:update( frame )
		local now = frame.now
		local vx, vy = frame.vx, frame.vy
		local abilities = self.abilities

		result.impulseY = 0
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
			vx = facing * config.dash.speed * config.dash.endFactor
			vy = 0

			-- The keys wait a moment, so the carried speed is not replaced on the same frame.
			controlLockedUntil = now + config.dash.carryTime
		end

		if isOnGround and not isDashing then
			hasDash = true
			hasAirJump = true
		end

		if frame.isDashPressed and abilities.dash and hasDash and not isDashing then
			-- The held direction wins over the facing, which otherwise updates only further down this frame.
			if frame.runDirection ~= 0 then
				facing = frame.runDirection
			end

			isDashing = true
			hasDash = false
			isJumping = false
			dashEndsAt = now + config.dash.time
			result.event = "dash"
		end

		if isDashing then
			result.vx = facing * config.dash.speed
			result.vy = 0
			result.gravityScale = 0
			result.facing = facing

			return result
		end

		local wantsJump = now - jumpPressedAt <= config.jumpBufferTime
		local canGroundJump = now - lastGroundedAt <= config.coyoteTime

		if wantsJump and ( canGroundJump or ( abilities.doubleJump and hasAirJump ) ) then
			vy = 0
			result.impulseY = -config.jumpImpulse
			result.event = "jump"

			-- Out of coyote time the jump is the air jump, which comes back on landing.
			if not canGroundJump then
				hasAirJump = false
				result.impulseY = -config.airJumpImpulse
			end

			isJumping = true
			lastGroundedAt = -math.huge
			jumpPressedAt = -math.huge

		elseif isJumping and ( vy >= 0 or not frame.isJumpHeld ) then
			-- Letting go of jump while still rising cuts the jump short.
			if vy < 0 then
				vy = vy * config.jumpCut
			end

			isJumping = false
		end

		if now >= controlLockedUntil then
			vx = frame.runDirection * config.runSpeed

			if frame.runDirection ~= 0 then
				facing = frame.runDirection
			end
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
