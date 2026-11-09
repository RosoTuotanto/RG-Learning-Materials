-- Tile queries over a ponytiled map; the typed objects on its "game" layer mark the start, the field plots and the bed.

local mapGrid = {}

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor

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

	local tilesByType = {}
	local typeAt = {}

	function grid:tileToWorld( column, row )
		return ( column - 0.5 ) * size, ( row - 0.5 ) * size
	end

	function grid:worldToTile( x, y )
		return floor( x / size ) + 1, floor( y / size ) + 1
	end

	-- Returns the tile of every game object of the type, as a list of tables with column and row.
	function grid:findTiles( objectType )
		return tilesByType[objectType] or {}
	end

	-- Returns the type of the game object on the tile, or nil when the tile has none.
	function grid:getObjectType( column, row )
		return typeAt[row] and typeAt[row][column]
	end

	-- Objects are matched by type, so a plot added in Tiled only needs its class set to "field".
	local objects = map:findLayer( "game" )
	for i = 1, objects.numChildren do
		local object = objects[i]
		local column, row = grid:worldToTile( object.x, object.y )

		tilesByType[object.type] = tilesByType[object.type] or {}
		tilesByType[object.type][#tilesByType[object.type] + 1] = { column = column, row = row }

		typeAt[row] = typeAt[row] or {}
		typeAt[row][column] = object.type
	end

	return grid
end

return mapGrid
