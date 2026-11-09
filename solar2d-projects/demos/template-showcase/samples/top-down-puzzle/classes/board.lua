-- Draws a puzzle room and tweens its hero and crates to match the room's state.

local board = {}

--------------------------------------------------------------------------------------
-- Public functions

-- room comes from puzzle.new; config is data/settings.lua board.
-- Tile ( 1, 1 )'s top-left corner sits at the group's origin.
function board.new( parent, room, config )
	local size = config.tileSize
	local images = config.images

	local view = display.newGroup()
	parent:insert( view )

	-- Plain fields, because setting width or height on a group with children rescales it.
	view.boardWidth = room.columnCount * size
	view.boardHeight = room.rowCount * size

	local crates = {}
	local doors = {}
	local tweens = {}

	local function tileToWorld( column, row )
		return ( column - 0.5 ) * size, ( row - 0.5 ) * size
	end

	local function newTileImage( image, column, row )
		local tile = display.newImageRect( view, image, size, size )
		tile.x, tile.y = tileToWorld( column, row )

		return tile
	end

	-- Idea: draw the rooms in Tiled and load them with ponytiled here instead of building them from string rows.
	for row = 1, room.rowCount do
		for column = 1, room.columnCount do
			local kind = room:getTile( column, row )

			if kind == "wall" then
				newTileImage( images.wall, column, row )

			else
				newTileImage( images.floor, column, row )

				if kind == "plate" then
					newTileImage( images.plate, column, row )

				elseif kind == "door" then
					doors[#doors + 1] = {
						closed = newTileImage( images.doorClosed, column, row ),
						open = newTileImage( images.doorOpen, column, row ),
					}
				end
			end
		end
	end

	for i = 1, #room.crates do
		crates[i] = newTileImage( images.crate, room.crates[i].column, room.crates[i].row )
	end

	-- The sprite sits in its own group so flipping it never moves the hero.
	local hero = display.newGroup()
	view:insert( hero )
	hero.sprite = display.newImageRect( hero, images.hero, size, size )

	view.isMoving = false

	-- Shows the door open or closed and tints every crate that covers a plate.
	function view:refresh()
		local isOpen = room:isDoorOpen()
		for i = 1, #doors do
			doors[i].closed.isVisible = not isOpen
			doors[i].open.isVisible = isOpen
		end

		for i = 1, #crates do
			local position = room.crates[i]
			if room:getTile( position.column, position.row ) == "plate" then
				crates[i]:setFillColor( unpack( config.crateOnPlate ) )

			else
				crates[i]:setFillColor( 1 )
			end
		end
	end

	function view:cancel()
		for i = #tweens, 1, -1 do
			transition.cancel( tweens[i] )
			tweens[i] = nil
		end

		self.isMoving = false
	end

	-- Stops any tween and places everything exactly where the room says it is.
	function view:sync()
		self:cancel()

		hero.x, hero.y = tileToWorld( room.hero.column, room.hero.row )
		for i = 1, #crates do
			crates[i].x, crates[i].y = tileToWorld( room.crates[i].column, room.crates[i].row )
		end

		self:refresh()
	end

	-- The front-view sprite only flips sideways; vertical steps keep the last facing.
	function view:face( directionX )
		if directionX ~= 0 then
			hero.sprite.xScale = directionX
		end
	end

	-- Tweens the hero and any crate the step pushed; onComplete runs once both have arrived.
	function view:animateStep( step, onComplete )
		self:cancel()
		self.isMoving = true

		local function onArrive()
			tweens = {}
			self.isMoving = false
			self:refresh()
			onComplete()
		end

		if step.crateIndex then
			local x, y = tileToWorld( room.crates[step.crateIndex].column, room.crates[step.crateIndex].row )
			tweens[#tweens + 1] = transition.to( crates[step.crateIndex], { x = x, y = y, time = config.stepTime } )
		end

		local x, y = tileToWorld( room.hero.column, room.hero.row )
		tweens[#tweens + 1] = transition.to( hero, { x = x, y = y, time = config.stepTime, onComplete = onArrive } )
	end

	view:sync()

	return view
end

return board
