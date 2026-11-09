local camera = {}

---------------------------------------------------------------------------------
-- State

local groups = {}
local bounds = nil
local target = nil
local targetParams = {
	xOffset = 0,
	yOffset = 0,
	paddingLeft = 0,
	paddingRight = 0,
	paddingUp = 0,
	paddingDown = 0,
	smoothing = 0,
	smoothingSettleTime = 2,
	maxDistance = display.actualContentHeight * 0.25
}
local lastTrackingTime = nil
local isTracking = false
local isMoving = false
local currentX = 0
local currentY = 0
local activeMovement = nil

local centerX = display.contentCenterX
local centerY = display.contentCenterY

local shakeOffsetX = 0
local shakeOffsetY = 0
local shakeTimer = nil

---------------------------------------------------------------------------------
-- Private functions

local mathRandom = math.random
local mathSqrt = math.sqrt
local mathExp = math.exp
local mathAbs = math.abs
local mathFloor = math.floor


local function cancelMovement()
	if activeMovement then
		Runtime:removeEventListener( "enterFrame", activeMovement )
		activeMovement = nil
	end
	isMoving = false
end


local function clamp( value, min, max )
	if value < min then return min end
	if value > max then return max end
	return value
end


local function applyPosition( x, y )
	currentX = x
	currentY = y

	-- Groups sit on whole content units: fractional positions open one-pixel seams between tiles.
	for i = 1, #groups do
		local entry = groups[i]
		entry.group.x = mathFloor( centerX - ( x * entry.delta ) + shakeOffsetX + 0.5 )
		entry.group.y = mathFloor( centerY - ( y * entry.delta ) + shakeOffsetY + 0.5 )
	end
end


local function getClampedPosition( x, y )
	if bounds then
		x = clamp( x, bounds.xMin, bounds.xMax )
		y = clamp( y, bounds.yMin, bounds.yMax )
	end
	return x, y
end


local function getIdealPosition( params )
	if not target then
		return currentX, currentY
	end

	local idealX = target.x - params.xOffset
	local idealY = target.y - params.yOffset

	return getClampedPosition( idealX, idealY )
end

-- Dead-zone is centered on ideal position. Camera stays put if within padding range,
-- otherwise moves to the nearest edge of the dead-zone.
local function calculateTrackingPosition( params )
	if not target then
		return currentX, currentY
	end

	local idealX, idealY = getIdealPosition( params )

	local desiredX = currentX
	local desiredY = currentY

	local dx = idealX - currentX
	local dy = idealY - currentY

	if dx > params.paddingRight then
		desiredX = idealX - params.paddingRight
	elseif dx < -params.paddingLeft then
		desiredX = idealX + params.paddingLeft
	end

	if dy > params.paddingDown then
		desiredY = idealY - params.paddingDown
	elseif dy < -params.paddingUp then
		desiredY = idealY + params.paddingUp
	end

	return getClampedPosition( desiredX, desiredY )
end

-- Used only by camera.move() for cutscene-style movement when tracking is off
local function startEasedMovement( params )
	cancelMovement()
	isMoving = true

	local startX = params.startX
	local startY = params.startY
	local targetX = params.targetX
	local targetY = params.targetY
	local duration = params.duration
	local easingFunc = params.easingFunc or easing.linear
	local onComplete = params.onComplete
	local startTime = system.getTimer()
	local deltaX = targetX - startX
	local deltaY = targetY - startY

	local function onFrame()
		local elapsed = system.getTimer() - startTime

		if elapsed >= duration then
			applyPosition( targetX, targetY )
			Runtime:removeEventListener( "enterFrame", onFrame )
			activeMovement = nil
			isMoving = false
			if onComplete then
				onComplete()
			end
		else
			-- Solar2D easing signature: easing( t, tMax, start, delta )
			local newX = easingFunc( elapsed, duration, startX, deltaX )
			local newY = easingFunc( elapsed, duration, startY, deltaY )
			applyPosition( newX, newY )
		end
	end

	activeMovement = onFrame
	Runtime:addEventListener( "enterFrame", onFrame )
end


local function onTrackingFrame( event )
	-- Ensure that target exists and hasn't been removed
	if not target or target.x == nil then return end

	local desiredX, desiredY = calculateTrackingPosition( targetParams )
	local idealX, idealY = getIdealPosition( targetParams )

	local smoothing = targetParams.smoothing
	local newX, newY

	if smoothing <= 0 then
		newX, newY = desiredX, desiredY
	else
		local dt = 0
		if lastTrackingTime then
			dt = ( event.time - lastTrackingTime ) / 1000
		end
		lastTrackingTime = event.time

		if dt > 0 then
			local settleTime = smoothing * targetParams.smoothingSettleTime
			local k = 3 / settleTime
			local t = 1 - mathExp( -k * dt )

			newX = currentX + ( desiredX - currentX ) * t
			newY = currentY + ( desiredY - currentY ) * t
		else
			newX, newY = currentX, currentY
		end
	end

	-- Enforce maxDistance leash from ideal position
	local maxDist = targetParams.maxDistance
	if maxDist and maxDist > 0 then
		local leashDx = newX - idealX
		local leashDy = newY - idealY
		local dist = mathSqrt( leashDx * leashDx + leashDy * leashDy )

		if dist > maxDist then
			local ratio = maxDist / dist
			newX = idealX + leashDx * ratio
			newY = idealY + leashDy * ratio
		end
	end

	applyPosition( newX, newY )
end

---------------------------------------------------------------------------------
-- Public functions

-- groups: { { group = displayGroup, delta = 1.0 }, ... }
-- delta controls parallax speed (1.0 = moves with camera, <1 = slower/background)
function camera.init( groupsTable )
	groups = groupsTable or {}
	currentX = 0
	currentY = 0
	applyPosition( 0, 0 )
end

-- bounds: { xMin, yMin, xMax, yMax }
function camera.setBounds( boundsTable )
	bounds = boundsTable
end

-- Offset positions target relative to screen center.
-- Padding creates a dead-zone where camera won't move until target exceeds it.
-- Smoothing controls tracking lerp (0 = instant, higher = smoother/slower).
-- maxDistance limits how far camera can lag behind ideal position (leash).
function camera.setTarget( targetObject, params )
	target = targetObject
	params = params or {}

	targetParams = {
		xOffset = tonumber( params.xOffset ) or 0,
		yOffset = tonumber( params.yOffset ) or 0,
		paddingLeft = mathAbs( params.paddingLeft or 0 ),
		paddingRight = mathAbs( params.paddingRight or 0 ),
		paddingUp = mathAbs( params.paddingUp or 0 ),
		paddingDown = mathAbs( params.paddingDown or 0 ),
		smoothing = mathAbs( params.smoothing or 0 ),
		smoothingSettleTime = mathAbs( params.smoothingSettleTime or 2 ),
		maxDistance = mathAbs( params.maxDistance or ( display.actualContentHeight * 0.25 ) )
	}
end

-- Immediately snaps the camera to the target's ideal position without starting tracking.
-- Useful for setting the correct camera position before the scene is first rendered.
function camera.snapToTarget()
	if target then
		local idealX, idealY = getIdealPosition( targetParams )
		applyPosition( idealX, idealY )
	end
end

-- Starts tracking the target. Snaps to ideal position (respecting smoothing), then tracks.
-- params: { onComplete }
function camera.start()
	if isTracking and not activeMovement then return end

	cancelMovement()
	isTracking = true
	lastTrackingTime = nil

	-- Snap to ideal position if not currently tracking
	if target then
		local idealX, idealY = getIdealPosition( targetParams )
		applyPosition( idealX, idealY )
	end

	Runtime:addEventListener( "enterFrame", onTrackingFrame )
end


function camera.stop()
	if not isTracking then return end

	cancelMovement()
	isTracking = false
	Runtime:removeEventListener( "enterFrame", onTrackingFrame )
end

-- Manual camera movement for cutscenes, etc. Ignored while tracking is active.
-- params: { x, y, movement = "absolute"|"relative", time, easing, onComplete }
function camera.move( params )
	if isTracking then return end

	cancelMovement()

	params = params or {}
	local movement = params.movement or "absolute"
	local targetX = params.x or 0
	local targetY = params.y or 0

	if movement == "relative" then
		targetX = currentX + targetX
		targetY = currentY + targetY
	end

	targetX, targetY = getClampedPosition( targetX, targetY )

	if params.time and params.time > 0 then
		startEasedMovement( {
			startX = currentX,
			startY = currentY,
			targetX = targetX,
			targetY = targetY,
			duration = params.time,
			easingFunc = params.easing or easing.linear,
			onComplete = params.onComplete
		} )
	else
		applyPosition( targetX, targetY )
		if params.onComplete then
			params.onComplete()
		end
	end
end

-- Returns a table with current camera position and visible viewport bounds.
-- x, y: current camera center position in world coordinates
-- xMin, xMax: left and right edges of visible area in world coordinates
-- yMin, yMax: top and bottom edges of visible area in world coordinates
function camera.getPosition()
	local halfWidth = display.actualContentWidth * 0.5
	local halfHeight = display.actualContentHeight * 0.5

	return {
		x = currentX,
		y = currentY,
		xMin = currentX - halfWidth,
		xMax = currentX + halfWidth,
		yMin = currentY - halfHeight,
		yMax = currentY + halfHeight
	}
end


function camera.isTracking()
	return isTracking
end


function camera.isMoving()
	return isMoving
end

-- Shakes the camera with configurable parameters.
-- params: { time = duration in ms, magnitude = shake strength in pixels, shakeCount = number of shake steps }
function camera.shake( params )
	params = params or {}

	local duration = mathAbs( params.time or 300 )
	local magnitude = mathAbs( params.magnitude or 4 )
	local shakeCount = mathAbs( params.shakeCount or 16 )

	-- Stop any existing shake first
	camera.shakeStop()

	local shakeIndex = 0

	local function doShake()
		shakeIndex = shakeIndex + 1

		if shakeIndex <= shakeCount then
			shakeOffsetX = mathRandom( -magnitude, magnitude )
			shakeOffsetY = mathRandom( -magnitude, magnitude )

			applyPosition( currentX, currentY )

			shakeTimer = timer.performWithDelay( duration / shakeCount, doShake )
		else
			shakeOffsetX = 0
			shakeOffsetY = 0
			shakeTimer = nil
			applyPosition( currentX, currentY )
		end
	end

	doShake()
end


function camera.shakeStop()
	if shakeTimer then
		timer.cancel( shakeTimer )
		shakeTimer = nil
	end

	shakeOffsetX = 0
	shakeOffsetY = 0
	applyPosition( currentX, currentY )
end


return camera