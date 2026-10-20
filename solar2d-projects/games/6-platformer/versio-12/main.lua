-- Asetetaan näytön asetukset, kuten piilotetaan statusbar ja
-- määritetään tekstuurifiltterit pikseligrafiikalle sopiviksi.
display.setStatusBar( display.HiddenStatusBar )
display.setDefault("magTextureFilter", "nearest")
display.setDefault("minTextureFilter", "nearest")

------------------------------------------------------------
-- Ladataan pelin asetukset ja laitetaan ne päälle.

-- Ladataan userdata tiedosto, jossa on käyttäjän asetukset:
local loadsave = require( "scripts.loadsave" )
local userdata = loadsave.load( "userdata.json" )

-- Jos userdataa ei löydy, niin luodaan se:
if not userdata then
	userdata = require( "data.defaultSettings" )
	loadsave.save( userdata, "userdata.json" )
end

-- Kopioidaan userdata loadsave moduuliin:
loadsave.userdata = {}
for k, v in pairs( userdata ) do
	loadsave.userdata[k] = v
end

local sfx = require( "scripts.sfx" )
sfx.update()

if loadsave.userdata["fullscreen"] then
	native.setProperty( "windowMode", "fullscreen" )
else
	native.setProperty( "windowMode", "normal" )
end

------------------------------------------------------------

-- Siirrytään heti pelin menu näkymään.
local composer = require( "composer" )
-- Käytetään automaattista muistinhallintaa scenejen välillä.
composer.recycleOnSceneChange = true
-- composer.gotoScene( "scenes.menu", { effect = "fade", time = 500 } )

-- Testataan suoraan pelinäkymää:
composer.gotoScene( "scenes.game", {
	effect = "fade",
	time = 0, -- Ladataan kenttä heti.
	params = {
		level = "tutorial.json"
	}
})
