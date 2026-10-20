local goal = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sfxComplete = audio.loadSound( "assets/audio/sfx/complete.wav" )

local sheet = graphics.newImageSheet( "assets/images/tiles/tilemap.png", {
	width = 18,
	height = 18,
	numFrames = 64
} )


local animation = {
	{
		name = "idle",
		frames = { 7, 15 },
		time = 200,
		loopCount = 0
	},
}

----------------------------------------------------------------------------------

function goal.new( parent, reference )
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

	function object:complete()
		self.xScale, self.yScale = 2, 2

		audio.play( sfxComplete, {
			channel = audio.findFreeChannel(2),
		})
	end

	return object
end

return goal