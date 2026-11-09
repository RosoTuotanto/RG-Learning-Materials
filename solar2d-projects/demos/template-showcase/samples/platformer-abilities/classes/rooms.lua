-- Splits the level into equal rooms and tells which room a world position is in.

local rooms = {}

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor
local max = math.max
local min = math.min

--------------------------------------------------------------------------------------
-- Public functions

-- mapData is the decoded Tiled map, whose roomColumns and roomRows properties give a room's size in tiles;
-- margin is how far past a room edge the player must be before the next room counts (settings.roomMargin).
function rooms.new( mapData, margin )
	local map = { entries = {} }

	local properties = {}
	for i = 1, #mapData.properties do
		properties[mapData.properties[i].name] = mapData.properties[i].value
	end

	local width = properties.roomColumns * mapData.tilewidth
	local height = properties.roomRows * mapData.tileheight
	local across = floor( mapData.width / properties.roomColumns )
	local down = floor( mapData.height / properties.roomRows )

	-- Positions outside the level count as the nearest room, so falling out keeps the room the player fell from.
	function map:indexAt( x, y )
		local column = max( 1, min( floor( x / width ) + 1, across ) )
		local row = max( 1, min( floor( y / height ) + 1, down ) )

		return ( row - 1 ) * across + column
	end

	-- Keeps the current room until x, y is margin deep into another, so standing on an edge never swings the camera back and forth.
	function map:indexFrom( current, x, y )
		local index = self:indexAt( x, y )
		if index == current then
			return current
		end

		local isDeep = self:indexAt( x - margin, y ) == index and self:indexAt( x + margin, y ) == index
			and self:indexAt( x, y - margin ) == index and self:indexAt( x, y + margin ) == index

		return isDeep and index or current
	end

	function map:centerOf( index )
		local column = ( index - 1 ) % across
		local row = floor( ( index - 1 ) / across )

		return ( column + 0.5 ) * width, ( row + 0.5 ) * height
	end

	-- Camera bounds that hold the camera still on the room's centre.
	function map:boundsOf( index )
		local x, y = self:centerOf( index )

		return { xMin = x, xMax = x, yMin = y, yMax = y }
	end

	-- Each point becomes the entry point of the room it lies in, where the player respawns after a fall.
	function map:setEntries( points )
		for i = 1, #points do
			self.entries[self:indexAt( points[i].x, points[i].y )] = points[i]
		end
	end

	return map
end

return rooms
