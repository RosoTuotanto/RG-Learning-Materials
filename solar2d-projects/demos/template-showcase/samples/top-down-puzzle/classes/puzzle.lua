-- The rules of one room: walls, crates, plates and the door, with an undo history. Uses no display objects.

local puzzle = {}

--------------------------------------------------------------------------------------
-- Public functions

-- rows are strings, one character per tile; symbols names the character for wall, crate, plate, door and start.
-- Tile ( 1, 1 ) is the top-left tile.
function puzzle.new( rows, symbols )
	local room = {
		columnCount = 0,
		rowCount = #rows,

		-- tiles[row][column] is "wall", "floor", "plate" or "door".
		tiles = {},
		plates = {},
		crates = {},
		hero = {},
		history = {},
	}

	local startCrates = {}
	local startColumn, startRow

	for row = 1, room.rowCount do
		local line = rows[row]
		room.tiles[row] = {}

		for column = 1, #line do
			local symbol = line:sub( column, column )
			local kind = "floor"

			if symbol == symbols.wall then
				kind = "wall"

			elseif symbol == symbols.plate then
				kind = "plate"
				room.plates[#room.plates + 1] = { column = column, row = row }

			elseif symbol == symbols.door then
				kind = "door"

			elseif symbol == symbols.crate then
				startCrates[#startCrates + 1] = { column = column, row = row }

			elseif symbol == symbols.start then
				startColumn, startRow = column, row
			end

			-- Idea: add keys and locked doors as another tile kind the hero picks up and spends here.
			room.tiles[row][column] = kind
		end

		room.columnCount = math.max( room.columnCount, #line )
	end

	-- Tiles outside the room count as wall.
	function room:getTile( column, row )
		return self.tiles[row] and self.tiles[row][column] or "wall"
	end

	-- Returns the index of the crate on the tile, or nil.
	function room:crateAt( column, row )
		for i = 1, #self.crates do
			local crate = self.crates[i]
			if crate.column == column and crate.row == row then
				return i
			end
		end

		return nil
	end

	function room:canHoldCrate( column, row )
		local tile = self:getTile( column, row )
		return ( tile == "floor" or tile == "plate" ) and not self:crateAt( column, row )
	end

	function room:isDoorOpen()
		for i = 1, #self.plates do
			if not self:crateAt( self.plates[i].column, self.plates[i].row ) then
				return false
			end
		end

		return true
	end

	function room:isExited()
		return self:getTile( self.hero.column, self.hero.row ) == "door"
	end

	function room:getMoveCount()
		return #self.history
	end

	-- Moves the hero one tile, pushing a crate in the way. Returns the step taken, or nil when blocked.
	-- A step holds where the hero came from and the index of the crate it pushed, if any.
	function room:move( directionX, directionY )
		local hero = self.hero
		local column = hero.column + directionX
		local row = hero.row + directionY

		local tile = self:getTile( column, row )
		if tile == "wall" or ( tile == "door" and not self:isDoorOpen() ) then
			return nil
		end

		local step = { column = hero.column, row = hero.row }

		-- Idea: add ice tiles that keep the hero or a pushed crate sliding until something stops it.
		local crateIndex = self:crateAt( column, row )
		if crateIndex then
			local behindColumn = column + directionX
			local behindRow = row + directionY
			if not self:canHoldCrate( behindColumn, behindRow ) then
				return nil
			end

			-- Idea: add more pushable kinds, such as barrels that roll until they hit something.
			local crate = self.crates[crateIndex]
			crate.column, crate.row = behindColumn, behindRow
			step.crateIndex = crateIndex
		end

		hero.column, hero.row = column, row
		self.history[#self.history + 1] = step

		return step
	end

	-- Takes back the latest step. Returns false when the room is already at its start.
	function room:undo()
		local step = table.remove( self.history )
		if not step then
			return false
		end

		local hero = self.hero

		-- A pushed crate always ends up one tile past the hero, so it goes back to where the hero stands.
		if step.crateIndex then
			local crate = self.crates[step.crateIndex]
			crate.column, crate.row = hero.column, hero.row
		end

		hero.column, hero.row = step.column, step.row

		return true
	end

	function room:restart()
		self.crates = {}
		for i = 1, #startCrates do
			self.crates[i] = { column = startCrates[i].column, row = startCrates[i].row }
		end

		self.hero.column, self.hero.row = startColumn, startRow
		self.history = {}
	end

	room:restart()

	return room
end

return puzzle
