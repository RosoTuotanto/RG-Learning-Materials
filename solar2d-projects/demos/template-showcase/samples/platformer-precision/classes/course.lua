-- Spike sensors and flags placed on the map's "game" layer points.

local course = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Private functions

local function newFlag( parent, sheet, sequence, position, kind )
	local flag = display.newSprite( parent, sheet, sequence )
	flag.x, flag.y = position.x, position.y
	flag.kind = kind
	physics.addBody( flag, "static", { isSensor = true } )

	return flag
end

--------------------------------------------------------------------------------------
-- Public functions

-- Only the bottom part of each spike tile hurts, where the points are drawn; each spike point is a tile centre.
function course.addSpikes( parent, map, size, hurtHeight )
	local height = size * hurtHeight
	local spots = map:findObjects( "spike" )

	for i = 1, #spots do
		local spike = display.newRect( parent, spots[i].x, spots[i].y + ( size - height ) * 0.5, size, height )
		spike.isVisible = false
		spike.kind = "spike"
		physics.addBody( spike, "static", { isSensor = true } )
	end
end

-- Each checkpoint keeps the spot where the player respawns, the spawn point in its column.
function course.addFlags( parent, map, sheet, config )
	local spots = map:findObjects( "checkpoint" )
	local spawns = map:findObjects( "spawn" )

	for i = 1, #spots do
		local flag = newFlag( parent, sheet, config.sequence, spots[i], "checkpoint" )
		flag.fill.effect = config.unlitEffect

		for j = 1, #spawns do
			if spawns[j].x == flag.x then
				flag.spawn = spawns[j]
			end
		end
	end

	local goal = newFlag( parent, sheet, config.sequence, map:findObject( "flag" ), "flag" )
	goal:play()
end

function course.lightCheckpoint( flag, config, tag )
	flag.isLit = true
	flag.fill.effect = nil
	flag:play()

	transition.from( flag, { xScale = config.popScale, yScale = config.popScale, time = config.popTime, tag = tag } )
end

return course
