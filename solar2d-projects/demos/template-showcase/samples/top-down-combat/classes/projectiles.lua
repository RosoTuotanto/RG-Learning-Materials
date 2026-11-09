-- Arrows as fast physics sensors in the world group, removed on their first hit or when their lifetime runs out.

local projectiles = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

local combat = require( "samples.top-down-combat.classes.combat" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent (the world group), config (settings.arrows), filters (settings.filters) and tag for the deferred hits.
function projectiles.new( params )
	local config = params.config

	local volley = {}
	local flying = {}

	local function removeArrow( arrow )
		if flying[arrow] then
			flying[arrow] = nil
			display.remove( arrow )
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

			if other.takeHit then
				other:takeHit( self.damage, self.x, self.y )
			end

			removeArrow( self )
		end, 1, params.tag )
	end

	-- side is "hero" or "enemy"; x, y is the shooter's centre and heading the direction in degrees.
	function volley:fire( side, x, y, heading )
		local sideConfig = config[side]
		local directionX, directionY = combat.direction( heading )

		local arrow = display.newImageRect( params.parent, config.image, config.width, config.height )
		arrow.x = x + directionX * config.muzzleOffset
		arrow.y = y + directionY * config.muzzleOffset
		arrow.rotation = heading

		physics.addBody( arrow, "dynamic", { isSensor = true, filter = params.filters[sideConfig.filter] } )
		arrow:setLinearVelocity( directionX * sideConfig.speed, directionY * sideConfig.speed )

		arrow.damage = sideConfig.damage
		arrow.timeLeft = sideConfig.lifetime

		arrow.collision = onCollision
		arrow:addEventListener( "collision" )

		flying[arrow] = true
	end

	-- deltaTime is in milliseconds.
	function volley:update( deltaTime )
		for arrow in pairs( flying ) do
			arrow.timeLeft = arrow.timeLeft - deltaTime

			if arrow.timeLeft <= 0 then
				removeArrow( arrow )
			end
		end
	end

	return volley
end

return projectiles
