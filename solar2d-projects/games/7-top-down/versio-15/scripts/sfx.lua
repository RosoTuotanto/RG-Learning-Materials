local sfx = {}

local loadsave = require( "scripts.loadsave" )

-- Varataan kanava 1 taustamusiikille. Muut kanavat jäävät ääniefekteille.
audio.reserveChannels( 1 )

-- Ladataan vuorovaikutuksen ääniefekti. Lyhyet ääniefektit ladataan loadSound:lla,
-- pitkä musiikki loadStream:lla (ks. scripts/music.lua).
local interactSound = audio.loadSound( "assets/audio/interact.wav" )

function sfx.update()
	local userdata = loadsave.userdata

	-- Ääniarvot tulee jakaa 100:lla, jotta niistä saadaan desimaaliarvot 1 ja 0 välillä.
	audio.setVolume( userdata.masterVolume / 100 ) -- Kanavaa ei määritetty, joten tämä vaikuttaa kaikkiin kanaviin.
	audio.setVolume( userdata.musicVolume / 100, { channel = 1 } ) -- Kanava 1, eli taustamusiikki.
	for i = 2, 32 do
		audio.setVolume( userdata.sfxVolume / 100, { channel = i } ) -- Kanavat 2-32, eli ääniefektit.
	end
end


-- Soitetaan vuorovaikutuksen ääniefekti. Kanavaa ei anneta, joten audio valitsee
-- vapaan kanavan väliltä 2-32, joita sfx.update ohjaa ääniefektien voimakkuudella.
function sfx.playInteract()
	audio.play( interactSound )
end


return sfx
