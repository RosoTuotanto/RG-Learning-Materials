-- World-space heading and offset maths shared by the gun, the turrets and the bullets.

local aim = {}

--------------------------------------------------------------------------------------
-- Localised functions

local atan2 = math.atan2
local cos = math.cos
local deg = math.deg
local rad = math.rad
local sin = math.sin

--------------------------------------------------------------------------------------
-- Public functions

-- Headings are in degrees like display rotation: 0 points along +x and 90 points down.
function aim.headingTo( fromX, fromY, toX, toY )
	return deg( atan2( toY - fromY, toX - fromX ) )
end

function aim.direction( heading )
	local angle = rad( heading )
	return cos( angle ), sin( angle )
end

-- Turns an offset given for art facing right (heading 0) to the heading, the way rotation turns the art.
function aim.rotate( offsetX, offsetY, heading )
	local directionX, directionY = aim.direction( heading )
	return offsetX * directionX - offsetY * directionY, offsetX * directionY + offsetY * directionX
end

function aim.distanceSquared( fromX, fromY, toX, toY )
	local deltaX, deltaY = toX - fromX, toY - fromY

	return deltaX * deltaX + deltaY * deltaY
end

return aim
