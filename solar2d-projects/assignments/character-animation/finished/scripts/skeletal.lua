local character = {}

local spriteloop = require( "com.ponywolf.spriteloop" )

-- Luodaan hahmo annettuun kohtaan. SpriteLoopissa tehdyt osat ja animaatiot ovat kaikki samassa .spla-tiedostossa.
function character.new( x, y )
	-- forceReload purkaa tiedoston joka käynnistyksellä uudelleen, joten SpriteLoopista uudelleen viety .spla näkyy heti.
	local player = spriteloop.new( "assets/character.spla", { forceReload = true } )
	player.x = x
	player.y = y

	player:play( "Idle" )

	return player
end

-- Vaihdetaan hahmo juoksemaan.
function character.run( player )
	player:play( "Run" )
end

-- Vaihdetaan hahmo seisomaan.
function character.stand( player )
	player:play( "Idle" )
end

return character
