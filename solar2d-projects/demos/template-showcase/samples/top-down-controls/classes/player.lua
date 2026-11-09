-- The hero, moved freely with Box2D velocity or one tile at a time on the map's tile grid.

local player = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, grid (classes/mapGrid.lua), input, config (data/settings.lua player), column and row of the start tile.
-- parent must be the group that holds the map, since tile positions are in that group's coordinates.
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

	hero.mode = "free"

	local stepTransition = nil
	local tryStep

	-- The front-view sprite only flips sideways; vertical movement keeps the last facing.
	local function face( directionX )
		if directionX < 0 then
			hero.sprite.xScale = -1

		elseif directionX > 0 then
			hero.sprite.xScale = 1
		end
	end

	local function onStepComplete()
		stepTransition = nil
		tryStep()
	end

	-- A press made during the previous step goes first, then a key still held keeps walking.
	function tryStep()
		local directionX, directionY = controls:takePressedDirection()
		if directionX == 0 and directionY == 0 then
			directionX, directionY = controls:getHeldDirection()
		end

		if directionX == 0 and directionY == 0 then
			return
		end

		face( directionX )

		local column = hero.column + directionX
		local row = hero.row + directionY
		if not grid:isWalkable( column, row ) then
			return
		end

		hero.column = column
		hero.row = row

		-- Idea: play a walk animation from a sprite sheet while the hero steps or moves.
		local x, y = grid:tileToWorld( column, row )
		stepTransition = transition.to( hero, { x = x, y = y, time = config.stepTime, onComplete = onStepComplete } )
	end

	function hero:placeOnTile( column, row )
		self.column = column
		self.row = row
		self.x, self.y = grid:tileToWorld( column, row )
	end

	-- Call once per frame.
	function hero:update()
		if self.mode == "free" then
			local directionX, directionY = controls:getMovement()
			face( directionX )
			self:setLinearVelocity( directionX * config.speed, directionY * config.speed )

		elseif not stepTransition then
			tryStep()
		end
	end

	-- Halts all movement; a step cut short finishes instantly on its target tile.
	function hero:stop()
		if stepTransition then
			transition.cancel( stepTransition )
			stepTransition = nil
			self:placeOnTile( self.column, self.row )
		end

		self:setLinearVelocity( 0, 0 )
	end

	-- mode is "free" or "grid".
	function hero:setMode( mode )
		self:stop()
		self.mode = mode
		controls:clearPressed()

		if mode == "grid" then
			-- The body radius keeps the hero's centre out of solid tiles, so the tile under it is free.
			self:placeOnTile( grid:worldToTile( self.x, self.y ) )
		end
	end

	hero:placeOnTile( params.column, params.row )

	return hero
end

return player
