-- Places the ability pickups and the goal flag on their map objects as sensors the player touches.

local pickups = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- Each pickup gets kind "pickup" and the name of its ability, which is both its object type on the map and its key in settings.abilities.
function pickups.addAbilities( parent, map, settings )
	local size = settings.sheets.tiles.displaySize
	local bob = settings.pickup

	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	for name, ability in pairs( settings.abilities ) do
		local spots = map:findObjects( name )

		for i = 1, #spots do
			local pickup = display.newImageRect( parent, ability.image, size, size )
			pickup.x, pickup.y = spots[i].x, spots[i].y
			pickup.kind = "pickup"
			pickup.ability = name

			physics.addBody( pickup, "static", { isSensor = true } )

			transition.to( pickup, {
				y = pickup.y - bob.bobHeight,
				time = bob.bobTime,
				iterations = -1,
				transition = easing.continuousLoop,
				tag = settings.tag,
			} )
		end
	end

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )
end

-- The flag gets kind "goal".
function pickups.addGoal( parent, map, sheet, config )
	local spots = map:findObjects( "flag" )

	for i = 1, #spots do
		local flag = display.newSprite( parent, sheet, config.sequence )
		flag.x, flag.y = spots[i].x, spots[i].y
		flag.kind = "goal"
		flag:play()

		physics.addBody( flag, "static", { isSensor = true } )
	end
end

return pickups
