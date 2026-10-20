-- Viestitriggereiden testiskripti. Ajaa pelin oikean maps/extensions/zone.lua-
-- extensionin lua5.1:ssä mockatuilla collision eventeillä ja tarkistaa laukeamislogiikan:
-- aina laukeava triggeri, kerran laukeava triggeri, rekisterin kartta-kohtaisuus sekä
-- tallennuksen palautus (restore) ja uuden pelin nollaus (reset).
--
-- Käyttö:  lua5.1 verify_zone.lua [versiokansio]
--   [versiokansio] = polku versiokansioon (oletus: ../versio-15).
--   Trigger-extension on olemassa vasta versiossa 15.

local projectDir = arg[1] or "../versio-15"
package.path = projectDir .. "/?.lua;" .. package.path

local failures = 0

local function check( condition, message )
	if condition then
		print( "  PASS  " .. message )
	else
		failures = failures + 1
		print( "  FAIL  " .. message )
	end
end

local zone = require( "maps.extensions.zone" )

print( "== trigger-testi (" .. projectDir .. ") ==" )

-- Viestit kerätään talteen onMessage-callbackilla, kuten pelinäkymä tekee.
local messages = {}
zone.onMessage = function( message )
	messages[#messages+1] = message
end

-- Mockattu ponytiled-objekti: extension saa Tiled-ominaisuudet suoraan kentistä
-- ja käyttää objektilta vain addEventListener/removeEventListener-funktioita.
local function makeInstance( name, message, once )
	local instance = { name = name, message = message, once = once, listeners = {} }
	function instance:addEventListener( eventName )
		self.listeners[eventName] = true
	end
	function instance:removeEventListener( eventName )
		self.listeners[eventName] = nil
	end
	return instance
end

local function enter( instance, otherName )
	instance:collision( { phase = "began", other = { name = otherName or "hero" } } )
end

-- 1. new kytkee event listenerit ja palauttaa saman objektin.
zone.reset()
zone.setMap( "village" )
local westZone = zone.new( makeInstance( "zoneWestRoad", "You: I don't want to go that way.", false ) )
check( westZone.listeners.collision and westZone.listeners.finalize, "new: collision- ja finalize-kuuntelijat kytketty" )

-- 2. Aina laukeava triggeri laukeaa jokaisella saapumisella.
enter( westZone )
enter( westZone )
check( #messages == 2, "aina laukeava triggeri laukeaa jokaisella saapumisella" )
check( messages[1] == "You: I don't want to go that way.", "viesti tulee objektin message-ominaisuudesta" )

-- 3. Muun kuin pelaajan törmäys ja törmäyksen päättyminen eivät laukaise triggeriä.
enter( westZone, "npcMarket" )
westZone:collision( { phase = "ended", other = { name = "hero" } } )
check( #messages == 2, "vain pelaajan saapuminen laukaisee triggerin" )

-- 4. Kerran laukeava triggeri laukeaa vain ensimmäisellä kerralla ja kirjautuu rekisteriin.
messages = {}
local northZone = zone.new( makeInstance( "zoneNorthRoad", "You: There seems to be some obstruction, I can't go this way.", true ) )
enter( northZone )
enter( northZone )
check( #messages == 1, "once-triggeri laukeaa vain kerran" )
check( zone.getTriggered().village.zoneNorthRoad == true, "once-laukeaminen kirjautuu rekisteriin kartan kohdalle" )

-- 5. Sama nimi toisella kartalla on eri triggeri: rekisteri on karttakohtainen.
zone.setMap( "house" )
local houseZone = zone.new( makeInstance( "zoneNorthRoad", "You: A different map, a different zone.", true ) )
enter( houseZone )
check( #messages == 2, "rekisteri on karttakohtainen (sama nimi eri kartalla laukeaa)" )

-- 6. restore palauttaa tallennetun rekisterin: jo lauennut once-triggeri ei laukea.
messages = {}
zone.restore( { village = { zoneNorthRoad = true } } )
zone.setMap( "village" )
local restoredZone = zone.new( makeInstance( "zoneNorthRoad", "You: There seems to be some obstruction, I can't go this way.", true ) )
enter( restoredZone )
check( #messages == 0, "restore: tallennuksessa jo lauennut once-triggeri ei laukea uudelleen" )

-- 7. reset tyhjentää rekisterin: uusi peli laukaisee once-triggerin taas.
zone.reset()
zone.setMap( "village" )
local freshZone = zone.new( makeInstance( "zoneNorthRoad", "You: There seems to be some obstruction, I can't go this way.", true ) )
enter( freshZone )
check( #messages == 1, "reset: uusi peli laukaisee once-triggerin uudelleen" )

-- 8. finalize irrottaa collision-listenerin kentän vaihdossa.
freshZone:finalize()
check( freshZone.listeners.collision == nil, "finalize: törmäyskuuntelija irtoaa" )

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI" )
	os.exit( 1 )
end
