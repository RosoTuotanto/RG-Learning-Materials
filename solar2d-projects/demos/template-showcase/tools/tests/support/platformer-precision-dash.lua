-- The final dash challenge: for a fixed dash spot, which jump presses before the dash carry the player past the last
-- spikes, simulated frame by frame with the real movement rules on the level's solid tiles.
-- Usage, from the demo root: lua5.1 tools/tests/support/platformer-precision-dash.lua [OLD_LEVEL_DATA]
-- Without an argument it reads the sample's map; with one, an old string level in the data/level.lua format.
-- Returns a table when required (dash.fromMap, dash.fromRows, dash.measure), prints a summary when run.
package.path = "./?.lua;" .. package.path

local movement = require( "samples.platformer-precision.classes.movement" )
local settings = require( "samples.platformer-precision.data.settings" )

local dash = {}

local config = settings.player
local body = config.body
local dt = 1 / 60
local frameTime = 1000 / 60
local pixelsPerMetre = 30
local gravity = settings.gravity * pixelsPerMetre

-- Solar2D gives density-less fixtures 0.01, so the three sensors add almost nothing.
local sensorArea = config.foot.width * config.foot.height + 2 * config.wallSensor.width * config.wallSensor.height
local area = body.width * body.height - 2 * body.chamfer * body.chamfer + sensorArea * 0.01
local mass = config.density * area / ( pixelsPerMetre * pixelsPerMetre )

local halfWidth = body.width * 0.5
local top = body.offsetY - body.height * 0.5
local bottom = body.offsetY + body.height * 0.5

local floor = math.floor

--------------------------------------------------------------------------------------
-- Courses: tileSize, isSolid( column, row ) and the spike tile centres

local function newCourse( tileSize, solidRows, spikes )
	local course = { tileSize = tileSize, spikes = spikes }

	function course.isSolid( column, row )
		return solidRows[row] ~= nil and solidRows[row][column] == true
	end

	return course
end

-- Solid cells come from the map's "level" layer and spikes from the "spike" objects on its "game" layer.
function dash.fromMap( path )
	local json = dofile( "tools/harness/stub/json.lua" )
	local map = assert( json.decodeFile( path ) )
	local solidRows, spikes = {}, {}

	for i = 1, #map.layers do
		local layer = map.layers[i]

		if layer.name == "level" then
			for index = 1, #layer.data do
				if layer.data[index] ~= 0 then
					local row = floor( ( index - 1 ) / layer.width ) + 1
					solidRows[row] = solidRows[row] or {}
					solidRows[row][( index - 1 ) % layer.width + 1] = true
				end
			end

		elseif layer.name == "game" then
			for j = 1, #layer.objects do
				local object = layer.objects[j]
				if object.type == "spike" then
					spikes[#spikes + 1] = { x = object.x, y = object.y }
				end
			end
		end
	end

	return newCourse( map.tilewidth, solidRows, spikes )
end

function dash.fromRows( rows, tileSize )
	local solidRows, spikes = {}, {}

	for row = 1, #rows do
		solidRows[row] = {}

		for column = 1, #rows[row] do
			local symbol = rows[row]:sub( column, column )
			solidRows[row][column] = symbol == "#"

			if symbol == "^" then
				spikes[#spikes + 1] = { x = ( column - 0.5 ) * tileSize, y = ( row - 0.5 ) * tileSize }
			end
		end
	end

	return newCourse( tileSize, solidRows, spikes )
end

--------------------------------------------------------------------------------------
-- Geometry

local function overlapsSolid( course, left, topY, right, bottomY )
	local size = course.tileSize

	for row = floor( topY / size ) + 1, floor( ( bottomY - 0.001 ) / size ) + 1 do
		for column = floor( left / size ) + 1, floor( ( right - 0.001 ) / size ) + 1 do
			if course.isSolid( column, row ) then
				return true
			end
		end
	end

	return false
end

-- The chamfered body against an axis-aligned rectangle, tested on the body's four edge directions.
local function bodyHitsRect( x, y, rect )
	local c = body.chamfer
	local left, right = x - halfWidth, x + halfWidth
	local upper, lower = y + top, y + bottom

	if right <= rect.left or left >= rect.right or lower <= rect.top or upper >= rect.bottom then
		return false
	end

	-- On the diagonals the body reaches its corners minus the chamfer; the rectangle reaches its nearest corner.
	local bodySum = ( right + lower ) - c
	local bodyMinSum = ( left + upper ) + c
	local bodyDifference = ( right - upper ) - c
	local bodyMinDifference = ( left - lower ) + c

	return bodySum > rect.left + rect.top and bodyMinSum < rect.right + rect.bottom
		and bodyDifference > rect.left - rect.bottom and bodyMinDifference < rect.right - rect.top
end

--------------------------------------------------------------------------------------
-- The challenge

-- The rightmost run of side-by-side spikes, as its hurting rectangle and the floor it sits on.
local function findChallenge( course )
	local size = course.tileSize
	local spikes = course.spikes
	local last = spikes[1]

	for i = 2, #spikes do
		if spikes[i].x > last.x then
			last = spikes[i]
		end
	end

	local first = last
	local isExtended = true
	while isExtended do
		isExtended = false

		for i = 1, #spikes do
			if spikes[i].y == first.y and math.abs( spikes[i].x - ( first.x - size ) ) < 0.5 then
				first = spikes[i]
				isExtended = true
			end
		end
	end

	local floorY = last.y + size * 0.5
	local hurtTop = floorY - size * settings.spike.hurtHeight

	return {
		hurt = { left = first.x - size * 0.5, right = last.x + size * 0.5, top = hurtTop, bottom = floorY },
		floorY = floorY,
	}
end

-- Runs right from startX holding jump from jumpFrame on, dashes on dashFrame; true if the player gets past the spikes untouched.
local function run( course, challenge, startX, jumpFrame, dashFrame )
	local mover = movement.new( config )
	local x, y = startX, challenge.floorY - bottom
	local vx, vy = 0, 0
	local hurt = challenge.hurt

	for frameIndex = 0, 400 do
		local feetY = y + bottom
		local footHalfWidth, footHalfHeight = config.foot.width * 0.5, config.foot.height * 0.5
		local isGrounded = overlapsSolid( course, x - footHalfWidth, feetY - footHalfHeight, x + footHalfWidth, feetY + footHalfHeight )

		local sensorTop = y + body.offsetY - config.wallSensor.height * 0.5
		local sensorBottom = sensorTop + config.wallSensor.height
		local sensorHalf = config.wallSensor.width * 0.5
		local wallSide = 0
		if overlapsSolid( course, x + halfWidth - sensorHalf, sensorTop, x + halfWidth + sensorHalf, sensorBottom ) then
			wallSide = 1

		elseif overlapsSolid( course, x - halfWidth - sensorHalf, sensorTop, x - halfWidth + sensorHalf, sensorBottom ) then
			wallSide = -1
		end

		local result = mover:update({
			now = frameIndex * frameTime,
			isGrounded = isGrounded,
			wallSide = wallSide,
			runDirection = 1,
			aimY = 0,
			isJumpHeld = frameIndex >= jumpFrame,
			isJumpPressed = frameIndex == jumpFrame,
			isDashPressed = frameIndex == dashFrame,
			vx = vx,
			vy = vy,
		})

		vx = result.vx + result.impulseX / mass * pixelsPerMetre
		vy = result.vy + result.impulseY / mass * pixelsPerMetre
		vy = vy + gravity * result.gravityScale * dt

		-- Sideways first, then up and down, each stopped flush against the tiles like a body with no bounce.
		local size = course.tileSize
		x = x + vx * dt
		if overlapsSolid( course, x - halfWidth, y + top, x + halfWidth, y + bottom ) then
			if vx > 0 then
				x = floor( ( x + halfWidth ) / size ) * size - halfWidth
			else
				x = ( floor( ( x - halfWidth ) / size ) + 1 ) * size + halfWidth
			end
			vx = 0
		end

		y = y + vy * dt
		if overlapsSolid( course, x - halfWidth, y + top, x + halfWidth, y + bottom ) then
			if vy > 0 then
				y = floor( ( y + bottom ) / size ) * size - bottom
			else
				y = ( floor( ( y + top ) / size ) + 1 ) * size - top
			end
			vy = 0
		end

		if bodyHitsRect( x, y, hurt ) then
			return false
		end

		if x - halfWidth > hurt.right then
			return true
		end

		if y > challenge.floorY + 400 then
			return false
		end
	end

	return false
end

-- The dash is pressed on the first frame the player's front is within dashDistance of the spikes, or never with
-- isWithoutDash. Returns the longest run of consecutive jump-press frames before that frame that succeed, in
-- milliseconds, and the frames tried.
function dash.measure( course, dashDistance, isWithoutDash )
	local challenge = findChallenge( course )
	local size = course.tileSize
	local hurt = challenge.hurt

	-- The run starts on the floor tile farthest left that has no spike or wall between it and the spikes.
	local column = floor( hurt.left / size )
	local row = floor( challenge.floorY / size )
	while column > 1 and not course.isSolid( column - 1, row ) and course.isSolid( column - 1, row + 1 ) do
		local isSpike = false
		for i = 1, #course.spikes do
			isSpike = isSpike or ( course.spikes[i].y == ( row - 0.5 ) * size and course.spikes[i].x == ( column - 1.5 ) * size )
		end

		if isSpike then
			break
		end

		column = column - 1
	end
	local startX = ( column - 1 ) * size + halfWidth

	local dashFrame = 0
	while startX + dashFrame * config.runSpeed * dt + halfWidth < hurt.left - dashDistance do
		dashFrame = dashFrame + 1
	end

	local best, current = 0, 0
	for lead = 0, dashFrame do
		if run( course, challenge, startX, dashFrame - lead, isWithoutDash and -1 or dashFrame ) then
			current = current + 1
			best = math.max( best, current )
		else
			current = 0
		end
	end

	return best * frameTime, dashFrame + 1
end

if arg and arg[0] and arg[0]:match( "platformer%-precision%-dash%.lua$" ) then
	local course
	local tileSize = settings.sheets.tiles.displaySize
	if arg[1] then
		course = dash.fromRows( dofile( arg[1] ).rows, tileSize )
	else
		course = dash.fromMap( "samples/platformer-precision/assets/level.json" )
	end

	for distance = 0, tileSize, tileSize / 4 do
		local window, tried = dash.measure( course, distance )
		local plain = dash.measure( course, distance, true )
		print( string.format( "dash %4.1f before the spikes: jump window %.0f ms (%d leads tried), %.0f ms without the dash", distance, window, tried, plain ) )
	end
end

return dash
