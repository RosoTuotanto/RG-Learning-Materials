-- Siirtymäportin testiskripti. Ajaa pelin oikean maps/extensions/exit.lua-extensionin
-- lua5.1:ssä mockatuilla collision eventeillä ja tarkistaa lukitun portin logiikan:
-- lukittu portti näyttää viestin eikä siirrä pelaajaa, tehtävän edettyä sama portti
-- siirtää, lukitsematon portti siirtää aina ja siirtymä käynnistyy vain kerran.
--
-- Käyttö:  lua5.1 verify_exit.lua [versiokansio]
--   [versiokansio] = polku versiokansioon (oletus: ../versio-15).
--   Portin lukitus on olemassa versiosta 11 alkaen.

local projectDir = arg[1] or "../versio-15"
package.path = projectDir .. "/?.lua;" .. package.path

------------------------------------------------------------------------------------
-- Stubit: composer kirjaa siirtymät, dialogue antaa tehtävätilan ja timer kerää
-- viivästetyt kutsut, jotta ne voidaan ajaa hallitusti.

local questValue = 0
local sceneChanges = {}
local pendingTimers = {}

package.loaded["composer"] = {
	gotoScene = function( sceneName, options )
		sceneChanges[#sceneChanges+1] = { sceneName = sceneName, params = options and options.params }
	end,
}

package.loaded["scripts.dialogue"] = {
	getFlag = function( name )
		if name == "quest" then
			return questValue
		end
	end,
}

timer = {
	performWithDelay = function( _, listener )
		pendingTimers[#pendingTimers+1] = listener
	end,
}

local function runTimers()
	local timers = pendingTimers
	pendingTimers = {}
	for index = 1, #timers do
		timers[index]()
	end
end

-- Mockattu Tiled-objekti. ponytiled kopioi objektin ominaisuudet suoraan kenttiin.
local function newInstance( properties )
	local instance = {}
	for key, value in pairs( properties ) do
		instance[key] = value
	end

	function instance:addEventListener() end
	function instance:removeEventListener() end

	return instance
end

local heroTouch = { phase = "began", other = { name = "hero" } }

------------------------------------------------------------------------------------
-- Assertit

local failures = 0

local function check( condition, message )
	if condition then
		print( "  PASS  " .. message )
	else
		failures = failures + 1
		print( "  FAIL  " .. message )
	end
end

local exitModule = require( "maps.extensions.exit" )

local lockedMessages = {}
function exitModule.onLocked( message )
	lockedMessages[#lockedMessages+1] = message
end

print( "== siirtymäportti-testi (" .. projectDir .. ") ==" )

-- 1. Lukitsematon portti siirtää pelaajan kohdekarttaan seuraavalla framella.
local openGate = exitModule.new( newInstance( { targetMap = "house", targetSpawn = "fromVillage" } ) )
openGate:collision( heroTouch )
check( #sceneChanges == 0, "siirtymää ei tehdä kesken törmäyskäsittelyn" )
runTimers()
check( #sceneChanges == 1 and sceneChanges[1].sceneName == "scenes.refresh", "lukitsematon portti siirtyy refresh-scenen kautta" )
local firstChange = sceneChanges[1]
check( firstChange and firstChange.params.mapName == "house" and firstChange.params.spawnName == "fromVillage",
	"siirtymä vie Tiled-ominaisuuksien kohdekarttaan ja spawn-pisteeseen" )

-- Kartta puretaan siirtymässä, jolloin finalize sallii siirtymät taas.
openGate:finalize()
sceneChanges = {}

-- 2. Siirtymä käynnistyy vain kerran, vaikka pelaaja koskettaisi porttia uudelleen.
openGate:collision( heroTouch )
openGate:collision( heroTouch )
runTimers()
check( #sceneChanges == 1, "toinen kosketus ennen siirtymää ei käynnistä toista siirtymää" )
openGate:finalize()
sceneChanges = {}

-- 3. Muut fysiikkaobjektit ja törmäyksen loppu eivät laukaise porttia.
openGate:collision( { phase = "began", other = { name = "npcMarket" } } )
openGate:collision( { phase = "ended", other = { name = "hero" } } )
runTimers()
check( #sceneChanges == 0, "vain pelaajan törmäyksen alku laukaisee portin" )

-- 4. Lukittu portti: ennen tehtävää pelaaja kommentoi eikä siirtymää tehdä.
local lockedGate = exitModule.new( newInstance( {
	targetMap = "sideroad",
	targetSpawn = "fromVillage",
	requiredQuest = 1,
	lockedMessage = "You: I don't have a reason to go there yet.",
} ) )

questValue = 0
lockedGate:collision( heroTouch )
runTimers()
check( #sceneChanges == 0, "lukittu portti ei siirrä pelaajaa ennen tehtävää" )
check( lockedMessages[1] == "You: I don't have a reason to go there yet.", "lukittu portti näyttää lockedMessage-viestin" )

lockedGate:collision( heroTouch )
check( #lockedMessages == 2, "viesti näytetään uudelleen jokaisella yrityksellä" )

-- 5. Tehtävän edettyä sama portti päästää läpi.
questValue = 1
lockedGate:collision( heroTouch )
runTimers()
check( #sceneChanges == 1 and sceneChanges[1].params.mapName == "sideroad", "portti aukeaa, kun quest saavuttaa requiredQuest-arvon" )
check( #lockedMessages == 2, "avautunut portti ei näytä lukitusviestiä" )
lockedGate:finalize()
sceneChanges = {}

questValue = 3
lockedGate:collision( heroTouch )
runTimers()
check( #sceneChanges == 1, "portti pysyy auki tehtävän myöhemmissä vaiheissa" )

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI" )
	os.exit( 1 )
end
