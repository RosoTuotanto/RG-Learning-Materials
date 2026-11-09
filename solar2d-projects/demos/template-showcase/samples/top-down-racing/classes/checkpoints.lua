-- Invisible checkpoint sensors and the checkered finish line, on the rects of the map's hidden "game" layer.

local checkpoints = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- Each checkpoint sensor carries checkpointIndex (the rect's order) and the finish sensor carries isFinish, for the car's
-- collision listener. style is settings.finishLine. Returns the number of checkpoints.
function checkpoints.new( parent, map, style )
	local gates = map:listTypes( "checkpoint" )

	for i = 1, #gates do
		physics.addBody( gates[i], "static", { isSensor = true } )
		gates[i].checkpointIndex = gates[i].order
	end

	local finish = map:findObject( "finish" )
	physics.addBody( finish, "static", { isSensor = true } )
	finish.isFinish = true

	local size = style.squareSize
	local left, top = finish.x - finish.width * 0.5, finish.y - finish.height * 0.5

	for column = 0, finish.width / size - 1 do
		for row = 0, finish.height / size - 1 do
			local square = display.newRect( parent, left + ( column + 0.5 ) * size, top + ( row + 0.5 ) * size, size, size )
			local isLight = ( column + row ) % 2 == 0
			square:setFillColor( unpack( isLight and style.lightColor or style.darkColor ) )
		end
	end

	return #gates
end

return checkpoints
