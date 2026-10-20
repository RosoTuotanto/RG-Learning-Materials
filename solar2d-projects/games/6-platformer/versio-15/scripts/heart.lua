local heart = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sfxCollect = audio.loadSound( "assets/audio/sfx/coin.wav" )

local sheet = graphics.newImageSheet( "assets/images/tiles/tilemap.png", {
	width = 18,
	height = 18,
	numFrames = 64
} )


local animation = {
	{
		name = "idle",
		frames = { 21, 21, 22 },
		time = 1000,
		loopCount = 0
	},
}

----------------------------------------------------------------------------------

function heart.new( parent, reference )
	-- Otetaan talteen objektin alkuperäinen sijainti kartalla.
	local x, y, id = reference.x, reference.y, reference.id
	display.remove( reference )

	local object = display.newSprite( sheet, animation )
	object.x, object.y = x, y
	object.id = id
	parent:insert( object )

	physics.addBody( object, "static", {
		isSensor = true,
	} )

	object:setSequence( "idle" )
	object:play()

	function object:collect()
		display.remove( self )

		audio.play( sfxCollect, {
			channel = audio.findFreeChannel(2),
		})
	end

	return object
end

return heart