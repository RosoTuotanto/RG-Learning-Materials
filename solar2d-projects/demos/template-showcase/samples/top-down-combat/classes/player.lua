-- The hero: Box2D velocity movement, a bow that follows the aim, and hit points.

local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local combat = require( "samples.top-down-combat.classes.combat" )

--------------------------------------------------------------------------------------
-- Localised functions

local max = math.max

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, x, y, input, filter, body, config (settings.player), reaction, flashColor and onHurt( hp ).
-- parent is the world group, so x, y and every aim point are world coordinates.
function player.new( params )
	local controls = params.input
	local config = params.config

	local hero = combat.newFighter({
		parent = params.parent,
		x = params.x,
		y = params.y,
		kind = "hero",
		filter = params.filter,
		body = params.body,
		config = config,
	})

	hero.hp = config.maxHp
	hero.aimHeading = 0

	local cooldownLeft = 0

	function hero:aimAt( worldX, worldY )
		self.aimHeading = combat.headingTo( self.x, self.y, worldX, worldY )
		self:face( self.aimHeading )
	end

	-- Returns true when an arrow may leave now, and starts the cooldown.
	function hero:tryShoot()
		if cooldownLeft > 0 or self.hp <= 0 then
			return false
		end

		cooldownLeft = config.shotCooldown

		return true
	end

	-- deltaTime is in milliseconds.
	function hero:update( deltaTime )
		cooldownLeft = max( 0, cooldownLeft - deltaTime )

		if combat.updateReaction( self, deltaTime, params.flashColor ) then
			return
		end

		local directionX, directionY = 0, 0
		if self.hp > 0 then
			directionX, directionY = controls:getMovement()
		end

		-- Idea: play walk and attack animations from a sprite sheet here instead of one still sprite.
		self:setLinearVelocity( directionX * config.speed, directionY * config.speed )
	end

	-- Arrows and swords call this; fromX, fromY is the world point the hit came from.
	function hero:takeHit( damage, fromX, fromY )
		if self.hp <= 0 then
			return
		end

		self.hp = max( 0, self.hp - damage )
		combat.hit( self, fromX, fromY, params.reaction )
		params.onHurt( self.hp )
	end

	function hero:stop()
		self.knockbackTimeLeft = 0
		self:setLinearVelocity( 0, 0 )
	end

	return hero
end

return player
