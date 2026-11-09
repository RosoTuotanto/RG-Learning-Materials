-- Tile queries over a ponytiled map; the wall rects on its "physics" layer decide which tiles are solid.

local mapGrid = {}

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor

--------------------------------------------------------------------------------------
-- Private functions

local function markWalls( solid, walls, size )
	for i = 1, walls.numChildren do
		local wall = walls[i]

		-- ponytiled centres each rect on its x and y; rounding keeps float edges on the tile they belong to.
		local firstColumn = floor( ( wall.x - wall.width * 0.5 ) / size + 0.5 ) + 1
		local firstRow = floor( ( wall.y - wall.height * 0.5 ) / size + 0.5 ) + 1
		local lastColumn = firstColumn + floor( wall.width / size + 0.5 ) - 1
		local lastRow = firstRow + floor( wall.height / size + 0.5 ) - 1

		for row = firstRow, lastRow do
			solid[row] = solid[row] or {}

			for column = firstColumn, lastColumn do
				solid[row][column] = true
			end
		end
	end
end

--------------------------------------------------------------------------------------
-- Public functions

-- mapData is the decoded map json. Tile ( 1, 1 ) is the top-left tile and its top-left corner sits at the map's origin.
function mapGrid.new( map, mapData )
	local size = mapData.tilewidth

	local grid = {
		tileSize = size,
		columnCount = mapData.width,
		rowCount = mapData.height,
		width = map.designedWidth,
		height = map.designedHeight,
	}

	local solid = {}
	markWalls( solid, map:findLayer( "physics" ), size )

	function grid:tileToWorld( column, row )
		return ( column - 0.5 ) * size, ( row - 0.5 ) * size
	end

	function grid:worldToTile( x, y )
		return floor( x / size ) + 1, floor( y / size ) + 1
	end

	-- Tiles outside the map are never walkable.
	function grid:isWalkable( column, row )
		if column < 1 or column > self.columnCount or row < 1 or row > self.rowCount then
			return false
		end

		-- Idea: let NPCs or crates block grid tiles by checking them here too.
		return not ( solid[row] and solid[row][column] )
	end

	-- Draws faint lines along every tile edge; style holds color and width.
	function grid:newGridOverlay( overlayParent, style )
		local overlay = display.newGroup()
		overlayParent:insert( overlay )

		for column = 0, self.columnCount do
			local line = display.newLine( overlay, column * size, 0, column * size, self.height )
			line:setStrokeColor( unpack( style.color ) )
			line.strokeWidth = style.width
		end

		for row = 0, self.rowCount do
			local line = display.newLine( overlay, 0, row * size, self.width, row * size )
			line:setStrokeColor( unpack( style.color ) )
			line.strokeWidth = style.width
		end

		return overlay
	end

	return grid
end

return mapGrid
