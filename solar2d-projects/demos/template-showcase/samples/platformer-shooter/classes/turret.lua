-- A turret standing on a platform: its barrel follows the player while it can see them, and it fires on an interval.

local turret = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

local aim = require( "samples.platformer-shooter.classes.aim" )

--------------------------------------------------------------------------------------
-- Localised functions

local getTimer = system.getTimer
local max = math.max

--------------------------------------------------------------------------------------
-- Public functions

-- Points are in world-group coordinates, which is what physics.rayCast works in; only level walls block sight.
function turret.canSee( fromX, fromY, toX, toY, range )
	if aim.distanceSquared( fromX, fromY, toX, toY ) > range * range then
		return false
	end

	local hits = physics.rayCast( fromX, fromY, toX, toY, "unsorted" )
	if hits then
		for i = 1, #hits do
			local object = hits[i].object
			if object.isGround and not object.isTurret then
				return false
			end
		end
	end

	return true
end

-- params: parent (the world group), x, y (the centre of the tile it stands in), filter, config (settings.turret) and onFire( x, y, heading ).
function turret.new( params )
	local config = params.config
	local barrelConfig = config.barrel

	local base = display.newImageRect( params.parent, config.image, config.size, config.size )
	base.x, base.y = params.x, params.y
	base.hp = config.hp

	-- The player can stand on a turret, but it never blocks another turret's sight.
	base.isGround = true
	base.isTurret = true

	local box = { halfWidth = config.body.width * 0.5, halfHeight = config.body.height * 0.5 }
	physics.addBody( base, "static", { box = box, bounce = 0, filter = params.filter } )

	local hubX, hubY = base.x + config.hub.x, base.y + config.hub.y

	local barrel = display.newImageRect( params.parent, barrelConfig.image, barrelConfig.width, barrelConfig.height )
	barrel.anchorX = barrelConfig.joint.x / barrelConfig.width
	barrel.anchorY = barrelConfig.joint.y / barrelConfig.height
	barrel.x, barrel.y = hubX, hubY
	barrel.rotation = config.restHeading

	local flashUntil = 0
	local nextShotAt = getTimer() + config.sightDelay

	-- targetX, targetY is the player's centre in world coordinates.
	function base:update( targetX, targetY )
		local now = getTimer()

		if now < flashUntil then
			self:setFillColor( unpack( config.flashColor ) )
			barrel:setFillColor( unpack( config.flashColor ) )
		else
			self:setFillColor( 1 )
			barrel:setFillColor( 1 )
		end

		-- Idea: add enemies that walk between cover spots and lean out to shoot.
		if not turret.canSee( hubX, hubY, targetX, targetY, config.range ) then
			nextShotAt = max( nextShotAt, now + config.sightDelay )
			return
		end

		barrel.rotation = aim.headingTo( hubX, hubY, targetX, targetY )

		if now >= nextShotAt then
			nextShotAt = now + config.fireInterval

			local directionX, directionY = aim.direction( barrel.rotation )
			params.onFire( hubX + directionX * config.muzzleOffset, hubY + directionY * config.muzzleOffset, barrel.rotation )
		end
	end

	-- Returns true when this hit destroys the turret.
	function base:takeHit( damage )
		self.hp = self.hp - damage
		flashUntil = getTimer() + config.flashTime

		return self.hp <= 0
	end

	function base:destroy()
		display.remove( barrel )
		barrel = nil

		display.remove( self )
	end

	return base
end

-- params: parent, spots (the map's turret points), filter, config and onFire as for turret.new; count is how many still stand.
function turret.newSquad( params )
	local squad = { count = 0 }
	local members = {}

	for i = 1, #params.spots do
		local spot = params.spots[i]
		local base = turret.new({ parent = params.parent, x = spot.x, y = spot.y, filter = params.filter, config = params.config, onFire = params.onFire })
		members[base] = true
		squad.count = squad.count + 1
	end

	function squad:update( targetX, targetY )
		for base in pairs( members ) do
			base:update( targetX, targetY )
		end
	end

	function squad:has( object )
		return members[object] == true
	end

	-- Removes the turret once the hit destroys it.
	function squad:hit( base, damage )
		if base:takeHit( damage ) then
			members[base] = nil
			self.count = self.count - 1
			base:destroy()
		end
	end

	return squad
end

return turret
