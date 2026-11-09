-- A guard that walks a looping waypoint route with a vision cone turning toward its way.

local guard = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Localised functions

local abs = math.abs
local atan2 = math.atan2
local cos = math.cos
local deg = math.deg
local max = math.max
local min = math.min
local rad = math.rad
local sin = math.sin
local sqrt = math.sqrt

--------------------------------------------------------------------------------------
-- Private functions

-- Returns the signed turn from one angle to another, in degrees between -180 and 180.
local function angleDifference( from, to )
	return ( to - from + 180 ) % 360 - 180
end

local function headingTo( fromX, fromY, toX, toY )
	return deg( atan2( toY - fromY, toX - fromX ) )
end

-- The cone opens around the positive x-axis, so its rotation is the guard's facing.
local function newCone( parent, vision, color )
	local vertices = { 0, 0 }
	local halfAngle = vision.halfAngle

	-- Idea: cast one ray per edge point and shorten it at the first wall, so walls visibly cut the cone.
	for i = 0, vision.arcSegments do
		local angle = rad( -halfAngle + 2 * halfAngle * i / vision.arcSegments )
		vertices[#vertices + 1] = vision.range * cos( angle )
		vertices[#vertices + 1] = vision.range * sin( angle )
	end

	local cone = display.newPolygon( parent, 0, 0, vertices )
	cone:setFillColor( unpack( color ) )

	-- A polygon is placed by its bounds; under 90 degrees the apex is the middle of the left edge.
	cone.anchorX = 0

	return cone
end

--------------------------------------------------------------------------------------
-- Public functions

-- True when the target is inside the cone's range and angle and no sight-blocking body lies between.
-- viewer and target share the world group with the walls, and Box2D casts the ray in that group's coordinates.
function guard.canSee( viewer, facing, target, vision )
	local fromX, fromY = viewer.x, viewer.y
	local toX, toY = target.x, target.y
	local deltaX, deltaY = toX - fromX, toY - fromY

	if deltaX * deltaX + deltaY * deltaY > vision.range * vision.range then
		return false
	end

	if abs( angleDifference( facing, headingTo( fromX, fromY, toX, toY ) ) ) > vision.halfAngle then
		return false
	end

	local hits = physics.rayCast( fromX, fromY, toX, toY, "unsorted" )
	if hits then
		for i = 1, #hits do
			if hits[i].object.blocksSight then
				return false
			end
		end
	end

	-- Idea: add hiding spots such as closets or tall grass, and return false while the hero is inside one.
	return true
end

-- Returns the points of a ponytiled polyline in its parent's coordinates, in the order they were drawn in Tiled.
function guard.routeFromLine( line )
	local points = line.points

	-- Tiled points are relative to the object, and ponytiled places the line at its first point.
	local originX = line.x - points[1].x
	local originY = line.y - points[1].y

	local route = {}
	for i = 1, #points do
		route[i] = { x = originX + points[i].x, y = originY + points[i].y }
	end

	return route
end

-- params: parent, coneParent, config (settings.guard), vision, colors, font and route (points from guard.routeFromLine).
function guard.new( params )
	local config = params.config
	local colors = params.colors
	local points = params.route

	local cone = newCone( params.coneParent, params.vision, colors.cone )

	local sentry = display.newGroup()
	params.parent:insert( sentry )

	sentry.sprite = display.newImageRect( sentry, config.image, config.size, config.size )

	local alertMark = display.newText({
		parent = sentry,
		text = config.alertText,
		x = 0,
		y = config.alertOffsetY,
		font = params.font,
		fontSize = config.alertSize,
	})
	alertMark:setFillColor( unpack( colors.alert ) )

	-- Kinematic, so the guard keeps to its route and pushes the hero aside instead of being pushed.
	physics.addBody( sentry, "kinematic", { radius = config.bodyRadius } )

	local targetIndex = 1
	local waitLeft = 0

	-- Degrees, 0 pointing right; the cone and the sight check both use it.
	sentry.facing = 0

	local function syncCone()
		cone.x, cone.y = sentry.x, sentry.y
		cone.rotation = sentry.facing
	end

	function sentry:reset()
		self:stop()
		alertMark.isVisible = false
		cone:setFillColor( unpack( colors.cone ) )

		self.x, self.y = points[1].x, points[1].y
		targetIndex = min( 2, #points )
		waitLeft = 0

		local target = points[targetIndex]
		self.facing = headingTo( self.x, self.y, target.x, target.y )
		syncCone()
	end

	-- deltaTime is the frame's length in seconds.
	function sentry:update( deltaTime )
		local target = points[targetIndex]
		local deltaX, deltaY = target.x - self.x, target.y - self.y
		local distance = sqrt( deltaX * deltaX + deltaY * deltaY )

		-- The guard keeps turning toward the next waypoint while it waits, so the cone sweeps round.
		if distance > 0 then
			local maxTurn = config.turnSpeed * deltaTime
			local turn = angleDifference( self.facing, headingTo( self.x, self.y, target.x, target.y ) )
			self.facing = self.facing + max( -maxTurn, min( maxTurn, turn ) )
		end

		if waitLeft > 0 then
			waitLeft = waitLeft - deltaTime * 1000

		else
			local step = config.speed * deltaTime

			if distance <= step then
				self.x, self.y = target.x, target.y
				targetIndex = targetIndex % #points + 1
				waitLeft = config.waitTime

			else
				self.x = self.x + deltaX / distance * step
				self.y = self.y + deltaY / distance * step
			end

			-- The front-view sprite only flips sideways, like the hero's.
			if deltaX < 0 then
				self.sprite.xScale = -1

			elseif deltaX > 0 then
				self.sprite.xScale = 1
			end
		end

		syncCone()
	end

	function sentry:alert()
		cone:setFillColor( unpack( colors.coneAlert ) )

		alertMark.isVisible = true
		alertMark.xScale, alertMark.yScale = config.alertStartScale, config.alertStartScale
		transition.to( alertMark, { xScale = 1, yScale = 1, time = config.alertPopTime, transition = easing.outBack } )
	end

	function sentry:stop()
		transition.cancel( alertMark )
	end

	sentry:reset()

	return sentry
end

return guard
