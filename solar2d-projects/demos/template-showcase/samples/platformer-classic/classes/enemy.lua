-- A walker that patrols the ground and turns around at walls and ledges.

local enemy = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, standingSheet, squashedSheet, x, y, isSolidAt (a function of world x and y), tag (for its transitions) and config (settings.enemy).
-- Idea: add more enemy types, such as a jumper or a flyer, as new classes with the same update and squash functions.
function enemy.new( params )
	local config = params.config
	local body = config.body

	-- A sprite can take each sequence from its own sheet, so squashing only switches the sequence.
	local walker = display.newSprite( params.parent, params.standingSheet, {
		{ name = "standing", frames = { 1 } },
		{ name = "squashed", sheet = params.squashedSheet, frames = { 1 } },
	} )
	walker.x, walker.y = params.x, params.y
	walker.kind = "enemy"

	local direction = config.startDirection
	walker.xScale = direction * config.artFacing

	-- A kinematic sensor ignores gravity and never pushes the player; contacts still report.
	physics.addBody( walker, "kinematic", {
		box = { halfWidth = body.width * 0.5, halfHeight = body.height * 0.5, x = 0, y = body.offsetY },
		isSensor = true,
		bounce = 0,
	} )

	local function isBlockedAhead()
		local aheadX = walker.x + direction * ( body.width * 0.5 + 1 )
		local feetY = walker.y + body.offsetY + body.height * 0.5

		return params.isSolidAt( aheadX, feetY - 1 ) or not params.isSolidAt( aheadX, feetY + 1 )
	end

	function walker:getTopY()
		return self.y + body.offsetY - body.height * 0.5
	end

	function walker:update()
		if isBlockedAhead() then
			direction = -direction
		end

		self.xScale = direction * config.artFacing
		self:setLinearVelocity( direction * config.speed, 0 )
	end

	-- Must run outside collision handlers, because it removes the body.
	function walker:squash()
		physics.removeBody( self )
		self:setSequence( "squashed" )

		transition.to( self, {
			alpha = 0,
			time = config.squashTime,
			tag = params.tag,
			onComplete = function()
				display.remove( self )
			end,
		} )
	end

	return walker
end

return enemy
