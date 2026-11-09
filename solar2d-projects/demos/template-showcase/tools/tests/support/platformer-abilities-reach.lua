-- Jump heights and chasm crossings from data/settings.lua, using the real movement rules.
-- Usage, from the demo root: lua5.1 tools/tests/support/platformer-abilities-reach.lua GAP CEILING
-- Returns a table when required (reach.heights, reach.crossingWindows, reach.crossesWithOneAbility), prints a summary when run.
package.path = "./?.lua;" .. package.path

local movement = require( "samples.platformer-abilities.classes.movement" )
local settings = require( "samples.platformer-abilities.data.settings" )

local reach = {}

local config = settings.player
local body = config.body
local frameTime = 1000 / 60
local dt = 1 / 60
local pixelsPerMetre = 30
local gravity = settings.gravity * pixelsPerMetre

-- Solar2D gives density-less fixtures 0.01, so the sensor adds almost nothing.
local area = body.width * body.height - 2 * body.chamfer * body.chamfer + config.foot.width * config.foot.height * 0.01
local mass = area / ( pixelsPerMetre * pixelsPerMetre )
local halfWidth = body.width * 0.5
local footHalf = config.foot.width * 0.5

-- Press frames searched after the ground jump, about two seconds.
local maxPressFrame = 120

-- How far below the floor an attempt counts as lost.
local maxDrop = 400

--------------------------------------------------------------------------------------
-- Simulation

-- One attempt on a floor whose top is y = 0 and whose right edge is x = 0; x is the body's centre, y its feet, down positive.
-- plan: startX, isRunning (holds right), jumpX (the ground jump is pressed once the centre reaches it; nil for none),
-- airFrame and dashFrame (frames after that press, or after reaching x = 0 without one; nil for never; each also grants its ability).
-- place: gap (the far side's left edge, nil for none) and ceiling (free height above the floor, nil for none).
-- Returns the highest rise of the feet and whether the body's leading edge reached the far side with the feet above its top.
local function simulate( plan, place )
	local mover = movement.new( config )
	mover.abilities.doubleJump = plan.airFrame ~= nil
	mover.abilities.dash = plan.dashFrame ~= nil

	local x, y, vx, vy = plan.startX, 0, 0, 0
	local baseFrame
	local highest = 0
	local farX = place.gap and place.gap - halfWidth

	for frameIndex = 0, maxPressFrame + 300 do
		if not baseFrame and x >= ( plan.jumpX or 0 ) then
			baseFrame = frameIndex
		end

		local since = baseFrame and frameIndex - baseFrame

		local result = mover:update({
			now = frameIndex * frameTime,
			isGrounded = x <= footHalf and y >= 0,
			runDirection = plan.isRunning and 1 or 0,
			isJumpHeld = true,
			isJumpPressed = ( since == 0 and plan.jumpX ~= nil ) or since == plan.airFrame,
			isDashPressed = since == plan.dashFrame,
			vx = vx,
			vy = vy,
		})

		vx = result.vx
		vy = result.vy + result.impulseY / mass * pixelsPerMetre + gravity * result.gravityScale * dt
		x, y = x + vx * dt, y + vy * dt

		-- The foot sensor still overlaps the near floor up to footHalf past its edge.
		if x <= footHalf and y >= 0 then
			y, vy = 0, 0
		end

		if place.ceiling and y - body.height < -place.ceiling then
			y = body.height - place.ceiling
			vy = math.max( vy, 0 )
		end

		highest = math.max( highest, -y )

		-- The chamfer lets feet just below the far top slide up onto it.
		if farX and x >= farX then
			return highest, y <= body.chamfer
		end

		if y > maxDrop then
			break
		end
	end

	return highest, false
end

--------------------------------------------------------------------------------------
-- Public functions

-- The highest rise of a standing jump, and of a standing jump followed by the best-timed air jump.
function reach.heights()
	local out = {}

	out.singleJump = simulate( { startX = 0, jumpX = 0 }, {} )

	out.doubleJump = 0
	for airFrame = 1, maxPressFrame do
		out.doubleJump = math.max( out.doubleJump, ( simulate( { startX = 0, jumpX = 0, airFrame = airFrame }, {} ) ) )
	end

	return out
end

-- Crossings of a gap gap units wide under a ceiling ceiling units above both floors (nil for none), running right from
-- runUp units before the edge, with both abilities and the ground jump pressed at the edge. Returns window, where
-- window[dashFrame] is the longest run of consecutive air jump frames that cross with that dash frame, in milliseconds,
-- the widest of those windows, and dashRange, the longest run of consecutive dash frames whose window is at least
-- minWindow milliseconds, in milliseconds.
function reach.crossingWindows( gap, ceiling, runUp, minWindow )
	local place = { gap = gap, ceiling = ceiling }
	local out = { window = {}, widestWindow = 0, dashRange = 0 }

	local rangeFrames = 0
	for dashFrame = 0, maxPressFrame do
		local run, longest = 0, 0

		for airFrame = 1, maxPressFrame do
			local _, crosses = simulate( { startX = -runUp, isRunning = true, jumpX = 0, airFrame = airFrame, dashFrame = dashFrame }, place )
			run = crosses and run + 1 or 0
			longest = math.max( longest, run )
		end

		local window = longest * frameTime
		out.window[dashFrame] = window
		out.widestWindow = math.max( out.widestWindow, window )

		rangeFrames = window >= minWindow and rangeFrames + 1 or 0
		out.dashRange = math.max( out.dashRange, rangeFrames * frameTime )
	end

	return out
end

-- Whether the same gap is crossed with the air jump alone and with the dash alone, trying ground jumps from two tiles
-- before the edge to the end of coyote time, running off without one, and every press frame.
function reach.crossesWithOneAbility( gap, ceiling, runUp )
	local place = { gap = gap, ceiling = ceiling }
	local withoutDash, withoutAirJump = false, false

	local jumpXs = { false }
	for jumpX = -72, footHalf + config.runSpeed * config.coyoteTime / 1000, 2 do
		jumpXs[#jumpXs + 1] = jumpX
	end

	for i = 1, #jumpXs do
		for pressFrame = 0, maxPressFrame do
			local plan = { startX = -runUp, isRunning = true, jumpX = jumpXs[i] or nil }

			plan.dashFrame = pressFrame
			withoutAirJump = withoutAirJump or select( 2, simulate( plan, place ) )

			plan.dashFrame, plan.airFrame = nil, math.max( pressFrame, 1 )
			withoutDash = withoutDash or select( 2, simulate( plan, place ) )
		end
	end

	return withoutDash, withoutAirJump
end

if arg and arg[0] and arg[0]:match( "reach%.lua$" ) then
	local gap, ceiling = tonumber( arg[1] ), tonumber( arg[2] )
	local heights = reach.heights()
	print( string.format( "mass %.4f  single jump %.1f  double jump %.1f", mass, heights.singleJump, heights.doubleJump ) )

	if gap then
		local out = reach.crossingWindows( gap, ceiling, 144, 400 )
		local withoutDash, withoutAirJump = reach.crossesWithOneAbility( gap, ceiling, 144 )

		local windows = {}
		for dashFrame = 0, maxPressFrame, 6 do
			windows[#windows + 1] = string.format( "%d:%.0f", math.floor( dashFrame * frameTime + 0.5 ), out.window[dashFrame] )
		end

		print( string.format( "gap %d, ceiling %s: widest jump window %.0f ms, dash range with a 400 ms window %.0f ms; crosses without dash %s, without air jump %s",
			gap, tostring( ceiling ), out.widestWindow, out.dashRange, tostring( withoutDash ), tostring( withoutAirJump ) ) )
		print( "dash ms:jump window ms  " .. table.concat( windows, " " ) )
	end
end

return reach
