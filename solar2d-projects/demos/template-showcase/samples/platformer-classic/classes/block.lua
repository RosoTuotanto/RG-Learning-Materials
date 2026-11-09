-- A block that releases one coin when the player bumps it from below.

local block = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, sheet, x, y (the tile centre), size (the tile size), tag (for its transitions) and config (settings.block).
function block.new( params )
	local config = params.config
	local halfSize = params.size * 0.5

	-- The art sits lower in its frame than the tile, so the sprite moves up and the body back down to match the tile.
	local box = display.newSprite( params.parent, params.sheet, config.sequence )
	box.x, box.y = params.x, params.y - config.artOffsetY
	box.kind = "block"
	box.isGround = true

	physics.addBody( box, "static", {
		box = { halfWidth = halfSize, halfHeight = halfSize, x = 0, y = config.artOffsetY },
		bounce = 0,
	} )

	local restY = box.y
	local isUsed = false

	function box:getBottomY()
		return self.y + config.artOffsetY + halfSize
	end

	function box:getTopY()
		return self.y + config.artOffsetY - halfSize
	end

	-- Must run outside collision handlers, because it moves the body; returns true only on the first bump.
	function box:bump()
		if isUsed then
			return false
		end

		isUsed = true
		self:setFrame( 2 )

		transition.to( self, { y = restY - config.bumpHeight, time = config.bumpTime, tag = params.tag } )
		transition.to( self, { y = restY, delay = config.bumpTime, time = config.bumpTime, tag = params.tag } )

		return true
	end

	return box
end

return block
