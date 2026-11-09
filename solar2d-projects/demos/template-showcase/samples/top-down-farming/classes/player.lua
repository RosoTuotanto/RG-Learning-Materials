-- The hero, moved freely with Box2D velocity, remembering which way it last moved.

local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Localised functions

-- Turns a movement component into a tile step of -1, 0 or 1.
local function toStep( value )
	if value > 0 then
		return 1

	elseif value < 0 then
		return -1
	end

	return 0
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, grid (classes/mapGrid.lua), input, config (data/settings.lua player), column and row of the start tile.
-- parent must be the group that holds the map, since tile positions are in the map's coordinates.
function player.new( params )
	local grid = params.grid
	local controls = params.input
	local config = params.config

	local hero = display.newGroup()
	params.parent:insert( hero )

	-- The sprite sits in its own group so flipping it never touches the physics body.
	hero.sprite = display.newImageRect( hero, config.image, config.size, config.size )

	physics.addBody( hero, "dynamic", { radius = config.bodyRadius, density = 1, friction = 0, bounce = 0 } )
	hero.isFixedRotation = true

	hero.facingX = config.startFacingX
	hero.facingY = config.startFacingY

	hero.x, hero.y = grid:tileToWorld( params.column, params.row )

	-- Call once per frame.
	function hero:update()
		local directionX, directionY = controls:getMovement()
		self:setLinearVelocity( directionX * config.speed, directionY * config.speed )

		-- Standing still keeps the last facing, so the target tile stays put.
		if directionX ~= 0 or directionY ~= 0 then
			self.facingX = toStep( directionX )
			self.facingY = toStep( directionY )
		end

		-- The front-view sprite only flips sideways.
		if self.facingX ~= 0 then
			self.sprite.xScale = self.facingX
		end
	end

	-- Returns the column and row of the tile one step from the hero in the facing direction, diagonals included.
	function hero:getTargetTile()
		local size = grid.tileSize

		return grid:worldToTile( self.x + self.facingX * size, self.y + self.facingY * size )
	end

	function hero:stop()
		self:setLinearVelocity( 0, 0 )
	end

	return hero
end

return player
