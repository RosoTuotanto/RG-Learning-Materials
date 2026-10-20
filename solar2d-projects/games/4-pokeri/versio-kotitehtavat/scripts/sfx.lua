local sfx = {}

audio.setVolume( 0.5 )

-- Lisätään kaikki äänet yhteen taulukkoon.
local sfxList = {

	-- Erotellaan eri tyyppiset äänet omiin alataulukoihin.

	cardDraw = {
		-- Lataamalla äänet näin, ne asettuvat taulukkoon
		-- tavallisesti numeeristen indeksien mukaan.
		audio.loadSound( "assets/sfx/card-place-1.ogg" ),
		audio.loadSound( "assets/sfx/card-place-2.ogg" ),
		audio.loadSound( "assets/sfx/card-place-3.ogg" ),
		audio.loadSound( "assets/sfx/card-place-4.ogg" ),
	},

	cardTouch = {
		audio.loadSound( "assets/sfx/card-shove-1.ogg" ),
		audio.loadSound( "assets/sfx/card-shove-2.ogg" ),
		audio.loadSound( "assets/sfx/card-shove-3.ogg" ),
	},

	cardDiscard = {
		audio.loadSound( "assets/sfx/card-slide-1.ogg" ),
		audio.loadSound( "assets/sfx/card-slide-2.ogg" ),
		audio.loadSound( "assets/sfx/card-slide-3.ogg" ),
		audio.loadSound( "assets/sfx/card-slide-4.ogg" ),
	},

	bet = {
		audio.loadSound( "assets/sfx/chip-lay-1.ogg" ),
		audio.loadSound( "assets/sfx/chip-lay-2.ogg" ),
		audio.loadSound( "assets/sfx/chip-lay-3.ogg" ),
	},

	win = {
		audio.loadSound( "assets/sfx/chips-collide-1.ogg" ),
		audio.loadSound( "assets/sfx/chips-collide-2.ogg" ),
		audio.loadSound( "assets/sfx/chips-collide-3.ogg" ),
	},
}

-- Soitetaan ääniefekti.
function sfx.play( sfxType )
	-- Valitaan satunnaisesti jokin ääniefekti annetusta kategoriasta.
	local randomSFX = math.random( #sfxList[sfxType] )

	-- Soitetaan valittu ääniefekti.
	local audioChannel = audio.play( sfxList[sfxType][randomSFX] )

	-- Palautetaan kanava, jos sitä tarvitaan myöhemmin.
	return audioChannel
end

return sfx