-- Tile queries over the ponytiled track: road tiles carry isTrack, and the wall rects on the "physics" layer mark solid tiles.

local mapGrid = {}

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor
local max = math.max
local min = math.min

--------------------------------------------------------------------------------------
-- Private functions

-- Returns the first and last column and row a centred rect covers.
local function getTileRange( rect, size )
	-- Rounding keeps float edges on the tile they belong to.
	local firstColumn = floor( ( rect.x - rect.width * 0.5 ) / size + 0.5 ) + 1
	local firstRow = floor( ( rect.y - rect.height * 0.5 ) / size + 0.5 ) + 1
	local lastColumn = firstColumn + floor( rect.width / size + 0.5 ) - 1
	local lastRow = firstRow + floor( rect.height / size + 0.5 ) - 1

	return firstColumn, firstRow, lastColumn, lastRow
end

local function markTile( tiles, column, row )
	tiles[row] = tiles[row] or {}
	tiles[row][column] = true
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

	local trackTiles = {}
	local solidTiles = {}

	function grid:worldToTile( x, y )
		return floor( x / size ) + 1, floor( y / size ) + 1
	end

	function grid:tileToWorld( column, row )
		return ( column - 0.5 ) * size, ( row - 0.5 ) * size
	end

	-- x and y are in the map's coordinates; tiles outside the map are not track.
	function grid:isTrackAt( x, y )
		local column, row = self:worldToTile( x, y )

		return ( trackTiles[row] and trackTiles[row][column] ) == true
	end

	-- Tiles outside the map are not solid.
	function grid:isSolid( column, row )
		return ( solidTiles[row] and solidTiles[row][column] ) == true
	end

	-- Returns the column and row of the wall rect's tile nearest to x and y.
	function grid:getNearestWallTile( wall, x, y )
		local firstColumn, firstRow, lastColumn, lastRow = getTileRange( wall, size )
		local column, row = self:worldToTile( x, y )

		return max( firstColumn, min( column, lastColumn ) ), max( firstRow, min( row, lastRow ) )
	end

	local roadTiles = map:getAllTiles( "isTrack" )
	for i = 1, #roadTiles do
		markTile( trackTiles, grid:worldToTile( roadTiles[i].x, roadTiles[i].y ) )
	end

	local walls = map:findLayer( "physics" )
	for i = 1, walls.numChildren do
		local firstColumn, firstRow, lastColumn, lastRow = getTileRange( walls[i], size )

		for row = firstRow, lastRow do
			for column = firstColumn, lastColumn do
				markTile( solidTiles, column, row )
			end
		end
	end

	return grid
end

return mapGrid
