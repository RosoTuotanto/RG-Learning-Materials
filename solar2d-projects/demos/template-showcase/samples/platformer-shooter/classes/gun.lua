local gun = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local aim = require( "samples.platformer-shooter.classes.aim" )

--------------------------------------------------------------------------------------
-- Public functions

-- Aiming to the left flips the gun vertically, so it is never drawn upside down.
function gun.getFlip( heading )
	local directionX = aim.direction( heading )
	return directionX < 0 and -1 or 1
end

-- Returns the tip's world position for a gun whose grip is at gripX, gripY; config is settings.gun.
function gun.getTip( gripX, gripY, heading, flip, config )
	local offsetX, offsetY = aim.rotate( config.tip.x - config.grip.x, ( config.tip.y - config.grip.y ) * flip, heading )
	return gripX + offsetX, gripY + offsetY
end

-- params: parent (the world group) and config (settings.gun).
function gun.new( params )
	local config = params.config

	local weapon = display.newImageRect( params.parent, config.image, config.width, config.height )
	weapon.anchorX = config.grip.x / config.width
	weapon.anchorY = config.grip.y / config.height
	weapon.heading = 0

	-- Idea: add weapon pickups that swap this gun's image, cooldown and fire pattern, such as a three-bullet spread.

	-- holder is the player sprite, whose facing picks the hand; aimX, aimY is the cursor in world coordinates.
	function weapon:aimAt( holder, aimX, aimY )
		self.x = holder.x + config.hand.x * holder.facing
		self.y = holder.y + config.hand.y

		self.heading = aim.headingTo( self.x, self.y, aimX, aimY )
		self.rotation = self.heading
		self.yScale = gun.getFlip( self.heading )
	end

	function weapon:getTip()
		return gun.getTip( self.x, self.y, self.heading, self.yScale, config )
	end

	return weapon
end

return gun
