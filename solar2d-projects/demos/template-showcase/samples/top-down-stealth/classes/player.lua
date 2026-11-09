-- The hero, moved freely with Box2D velocity.

local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, input, config (data/settings.lua player), and x and y of the start.
-- parent must be the group that holds the map, since map positions are in that group's coordinates.
function player.new( params )
	local controls = params.input
	local config = params.config

	local hero = display.newGroup()
	params.parent:insert( hero )

	-- The sprite sits in its own group so flipping it never touches the physics body.
	hero.sprite = display.newImageRect( hero, config.image, config.size, config.size )

	physics.addBody( hero, "dynamic", { radius = config.bodyRadius, density = 1, friction = 0, bounce = 0 } )
	hero.isFixedRotation = true

	-- The front-view sprite only flips sideways; vertical movement keeps the last facing.
	local function face( directionX )
		if directionX < 0 then
			hero.sprite.xScale = -1

		elseif directionX > 0 then
			hero.sprite.xScale = 1
		end
	end

	function hero:placeAt( x, y )
		self:setLinearVelocity( 0, 0 )
		self.x, self.y = x, y
	end

	-- Call once per frame.
	function hero:update()
		local directionX, directionY = controls:getMovement()
		face( directionX )
		self:setLinearVelocity( directionX * config.speed, directionY * config.speed )
	end

	function hero:stop()
		self:setLinearVelocity( 0, 0 )
	end

	hero:placeAt( params.x, params.y )

	return hero
end

return player
