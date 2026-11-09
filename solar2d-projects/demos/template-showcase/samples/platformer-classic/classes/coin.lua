-- Spinning coins: pickups placed in the level, and the coin a block releases.

local coin = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Private functions

local function newSpinningCoin( params )
	local sprite = display.newSprite( params.parent, params.sheet, params.config.sequence )
	sprite.x, sprite.y = params.x, params.y
	sprite:play()

	return sprite
end

local function flyAway( sprite, params )
	transition.to( sprite, {
		y = sprite.y - params.config.flyHeight,
		alpha = 0,
		time = params.config.flyTime,
		tag = params.tag,
		onComplete = function()
			display.remove( sprite )
		end,
	} )
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, sheet, x, y, tag (for its transitions) and config (settings.coin).
function coin.new( params )
	local pickup = newSpinningCoin( params )
	pickup.kind = "coin"

	physics.addBody( pickup, "static", { radius = params.config.radius, isSensor = true } )

	-- Must run outside collision handlers, because it removes the body.
	function pickup:collect()
		physics.removeBody( self )
		flyAway( self, params )
	end

	return pickup
end

-- Shows a coin flying out of a block; it has no body, so it only shows that the coin was counted.
function coin.release( params )
	flyAway( newSpinningCoin( params ), params )
end

return coin
