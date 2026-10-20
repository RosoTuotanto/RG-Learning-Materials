local trampoline = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sheet = graphics.newImageSheet( "assets/images/tiles/tilemap.png", {
	width = 18,
	height = 18,
	numFrames = 64
} )


local animation = {
	{
		name = "ready",
		frames = { 45 },
		time = 100,
		loopCount = 0
	},
	{
		name = "used",
		frames = { 46 },
		time = 100,
		loopCount = 0
	},
}

----------------------------------------------------------------------------------

function trampoline.new( parent, reference )
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

	object:setSequence( "ready" )

	local forceMultiplier = 2.5

	function object:use()
		self:setSequence( "used" )
		self:play()

		-- Poistetaan objektilta fysiikat seuraavan framen aikana.
		timer.performWithDelay( 1, function()
			physics.removeBody( self )
		end )

		return forceMultiplier
	end

	return object
end

return trampoline