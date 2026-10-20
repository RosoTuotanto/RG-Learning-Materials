local player = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sheet = graphics.newImageSheet( "assets/images/characters/characters.png", {
	width = 24,
	height = 24,
	numFrames = 10
} )


local animation = {
	{
		name = "move",
		start = 1,
		count = 2,
		time = 250,
		loopCount = 0,
		loopDirection = "forward"
	}
}

----------------------------------------------------------------------------------

-- Poistetaan vanha pelaajahahmon kuva kentästä ja luodaan uusi hahmo sen tilalle.
function player.new( parent, reference )
	-- Otetaan talteen pelaajan alkuperäinen sijainti kartalla.
	local x, y = reference.x, reference.y
	display.remove( reference )

	local newPlayer = display.newSprite( sheet, animation )
	newPlayer.x, newPlayer.y = x, y
	newPlayer.id = "player"
	parent:insert( newPlayer )

	physics.addBody( newPlayer, "dynamic", {
		radius=newPlayer.width*0.5,
		friction = 0.3,
		density = 0.5,
		bounce = 0,
	} )
	-- Estetään pelaajahahmoa pyörimästä fysiikoiden vaikutuksesta.
	newPlayer.isFixedRotation = true

	newPlayer:setSequence( "move" )
	newPlayer:play()

	return newPlayer
end

return player