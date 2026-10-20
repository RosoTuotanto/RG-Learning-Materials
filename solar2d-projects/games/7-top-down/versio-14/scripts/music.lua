-- Taustamusiikin hallinta. Musiikki soi kanavalla 1, jonka sfx-moduuli varaa.
-- Sama raita jatkuu, kun siirrytään saman ympäristön karttojen välillä (kylä ja
-- rantatie ovat ulkona), ja vaihtuu vasta, kun ympäristö muuttuu (talon sisälle).

local music = {}

--------------------------------------------------------------------------------------
-- Muuttujat

-- Ladataan molemmat raidat streamina, jotta ne eivät varaa paljon muistia kerralla.
local tracks = {
	outdoors = audio.loadStream( "assets/audio/outdoors.mp3" ),
	indoors = audio.loadStream( "assets/audio/indoors.mp3" ),
}

-- Jaetaan kartat ympäristöihin: ulkona soi outdoors-raita, sisällä indoors-raita.
local environmentOfMap = {
	village = "outdoors",
	sideroad = "outdoors",
	house = "indoors",
}

-- Parhaillaan soiva ympäristö. Kun se ei muutu, musiikkia ei aloiteta uudelleen.
local currentEnvironment

--------------------------------------------------------------------------------------
-- Julkiset funktiot

-- Soitetaan kartan mukainen taustaraita. Jos oikea raita jo soi, ei tehdä mitään,
-- jolloin musiikki jatkuu katkeamatta saman ympäristön karttojen välillä. Kokonaan
-- toinen tapa olisi käynnistää raita aina alusta joka siirtymässä (kerrotaan oppitunnilla).
function music.playForMap( mapName )
	local environment = environmentOfMap[mapName] or "outdoors"

	-- Sama ympäristö kuin ennen ja musiikki jo soi: annetaan sen jatkua.
	if environment == currentEnvironment and audio.isChannelPlaying( 1 ) then
		return
	end

	-- Ympäristö vaihtui: pysäytetään edellinen raita ja aloitetaan uusi kanavalla 1.
	audio.stop( 1 )
	currentEnvironment = environment
	audio.play( tracks[environment], { channel = 1, loops = -1 } )
end


-- Pysäytetään taustamusiikki. Kutsutaan, kun palataan päävalikkoon.
function music.stop()
	audio.stop( 1 )
	currentEnvironment = nil
end

--------------------------------------------------------------------------------------

return music
