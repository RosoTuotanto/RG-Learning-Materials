-- Bullets as fast physics sensors in the world group, removed on their first hit or when their lifetime runs out.

local bullets = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

local aim = require( "samples.platformer-shooter.classes.aim" )
local pixelArt = require( "samples.platformer-shooter.classes.pixelArt" )

--------------------------------------------------------------------------------------
-- Localised functions

local getTimer = system.getTimer

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent (the world group), config (settings.bullets), filters (settings.filters), tag for the deferred hits and onHit( other, damage, x, y ).
function bullets.new( params )
	local config = params.config

	local volley = {}
	local flying = {}

	local function removeBullet( bullet )
		if flying[bullet] then
			flying[bullet] = nil
			display.remove( bullet )
		end
	end

	local function onCollision( self, event )
		if event.phase ~= "began" or self.isSpent then
			return
		end

		self.isSpent = true
		local other = event.other

		-- Bodies cannot be changed or removed inside a collision handler, and a hit can do both.
		timer.performWithDelay( 1, function()
			if not flying[self] then
				return
			end

			params.onHit( other, self.damage, self.x, self.y )
			removeBullet( self )
		end, 1, params.tag )
	end

	-- side is "player" or "turret"; x, y is the muzzle and heading the direction in degrees.
	function volley:fire( side, x, y, heading )
		local sideConfig = config[side]
		local directionX, directionY = aim.direction( heading )

		-- The texture loads again whenever every bullet of its kind was gone.
		pixelArt.setFilter( true )
		local bullet = display.newImageRect( params.parent, sideConfig.image, sideConfig.width, sideConfig.height )
		pixelArt.setFilter( false )

		bullet.x, bullet.y = x, y
		bullet.rotation = heading

		physics.addBody( bullet, "dynamic", { isSensor = true, bounce = 0, filter = params.filters[sideConfig.filter] } )
		bullet.gravityScale = 0
		bullet:setLinearVelocity( directionX * sideConfig.speed, directionY * sideConfig.speed )

		bullet.damage = sideConfig.damage
		bullet.expiresAt = getTimer() + sideConfig.lifetime

		bullet.collision = onCollision
		bullet:addEventListener( "collision" )

		flying[bullet] = true
	end

	-- Leaving the scene cancels pending hits, so the bullets go too.
	function volley:clear()
		for bullet in pairs( flying ) do
			removeBullet( bullet )
		end
	end

	function volley:update()
		local now = getTimer()

		for bullet in pairs( flying ) do
			if now >= bullet.expiresAt then
				removeBullet( bullet )
			end
		end
	end

	return volley
end

return bullets
