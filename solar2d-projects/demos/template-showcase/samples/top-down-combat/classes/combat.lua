-- World-space aim and hit maths, plus the hit flash and knockback every fighter shares.

local combat = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Localised functions

local abs = math.abs
local atan2 = math.atan2
local cos = math.cos
local deg = math.deg
local rad = math.rad
local sin = math.sin

--------------------------------------------------------------------------------------
-- Public functions

-- Returns the signed turn from one heading to another, in degrees between -180 and 180.
function combat.angleDifference( from, to )
	return ( to - from + 180 ) % 360 - 180
end

-- Headings are in degrees like display rotation: 0 points along +x and 90 points down.
function combat.headingTo( fromX, fromY, toX, toY )
	return deg( atan2( toY - fromY, toX - fromX ) )
end

function combat.direction( heading )
	local angle = rad( heading )
	return cos( angle ), sin( angle )
end

function combat.distanceSquared( fromX, fromY, toX, toY )
	local deltaX, deltaY = toX - fromX, toY - fromY

	return deltaX * deltaX + deltaY * deltaY
end

-- True when the point is within reach of the centre and inside the arc around the heading.
function combat.isInArc( centerX, centerY, heading, halfArc, reach, x, y )
	if combat.distanceSquared( centerX, centerY, x, y ) > reach * reach then
		return false
	end

	return abs( combat.angleDifference( heading, combat.headingTo( centerX, centerY, x, y ) ) ) <= halfArc
end

-- params: parent, x, y, kind, filter, body (settings.fighterBody) and config (image, size, bodyRadius and weapon from data/settings.lua).
function combat.newFighter( params )
	local config = params.config

	local fighter = display.newGroup()
	params.parent:insert( fighter )
	fighter.x, fighter.y = params.x, params.y
	fighter.kind = params.kind

	fighter.sprite = display.newImageRect( fighter, config.image, config.size, config.size )

	-- The weapon sits on its own pivot at the centre, so turning the pivot swings it around the fighter.
	fighter.weaponPivot = display.newGroup()
	fighter:insert( fighter.weaponPivot )

	local weaponConfig = config.weapon
	local weapon = display.newImageRect( fighter.weaponPivot, weaponConfig.image, weaponConfig.width, weaponConfig.height )
	weapon.anchorX = weaponConfig.anchorX
	weapon.x = weaponConfig.offset

	local body = params.body
	physics.addBody( fighter, "dynamic", {
		radius = config.bodyRadius,
		density = body.density,
		friction = body.friction,
		bounce = body.bounce,
		filter = params.filter,
	} )
	fighter.isFixedRotation = true

	fighter.flashTimeLeft = 0
	fighter.knockbackTimeLeft = 0

	-- Points the weapon along the heading; the front-view sprite only flips toward that side.
	function fighter:face( heading )
		self.weaponPivot.rotation = heading
		self.sprite.xScale = abs( combat.angleDifference( 0, heading ) ) > 90 and -1 or 1
	end

	return fighter
end

-- Starts the flash and pushes the fighter directly away from the point the hit came from.
function combat.hit( fighter, fromX, fromY, reaction )
	local directionX, directionY = combat.direction( combat.headingTo( fromX, fromY, fighter.x, fighter.y ) )

	fighter.knockbackX = directionX * reaction.knockbackSpeed
	fighter.knockbackY = directionY * reaction.knockbackSpeed
	fighter.knockbackTimeLeft = reaction.knockbackTime
	fighter.flashTimeLeft = reaction.flashTime
end

-- Advances the flash and knockback; returns true while the knockback overrides the fighter's own movement.
function combat.updateReaction( fighter, deltaTime, flashColor )
	if fighter.flashTimeLeft > 0 then
		fighter.flashTimeLeft = fighter.flashTimeLeft - deltaTime

		if fighter.flashTimeLeft > 0 then
			fighter.sprite:setFillColor( unpack( flashColor ) )
		else
			fighter.sprite:setFillColor( 1 )
		end
	end

	if fighter.knockbackTimeLeft > 0 then
		fighter.knockbackTimeLeft = fighter.knockbackTimeLeft - deltaTime
		fighter:setLinearVelocity( fighter.knockbackX, fighter.knockbackY )

		return true
	end

	return false
end

return combat
