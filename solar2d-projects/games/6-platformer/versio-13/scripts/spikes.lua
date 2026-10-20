local spikes = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sheet = graphics.newImageSheet( "assets/images/tiles/tilemap.png", {
	width = 18,
	height = 18,
	numFrames = 64
} )

----------------------------------------------------------------------------------

function spikes.new( parent, reference )
	-- Otetaan talteen objektin alkuperäinen sijainti kartalla.
	local x, y, id = reference.x, reference.y, reference.id
	display.remove( reference )

	local object = display.newImage( sheet, 32 )
	object.x, object.y = x, y
	object.id = id
	parent:insert( object )

	physics.addBody( object, "static", {
		box = {
			halfWidth = object.width*0.5,
			halfHeight = object.height*0.25,
			x = 0,
			y = 4,
		},
		bounce = 1.5,
	} )

	return object
end


return spikes