-- Pelaajan reppu ja poimittujen esineiden rekisteri.
-- Tämä moduuli elää game-scenen ulkopuolella, joten sen tila säilyy, vaikka
-- game-scene rakennetaan kentän vaihdon yhteydessä kokonaan uudelleen.

local inventory = {}

--------------------------------------------------------------------------------------
-- Muuttujat

-- Reppu on ruudukko, jossa on kiinteä määrä slotteja. Slotit säilytetään
-- merkkijonoavaimin (slots["1"] = "note"), koska harva Lua-taulukko (slotteja
-- joiden välissä on tyhjää) ei säily ehjänä json.encode/json.decode -round tripin läpi.
-- Merkkijonoavaimin taulu serialisoituu aina JSON-objektiksi, joka dekoodautuu ennallaan.
inventory.slotCount = 8
inventory.slots = {}

-- Rekisteri jo poimituista esineistä: collected[kartta][objektinNimi] = true.
-- Näin kertaalleen poimittu esine ei ilmesty takaisin kentälle, kun palaamme sinne.
local collected = {}

-- Nykyinen kartta. Game-scene asettaa tämän ennen kentän rakentamista, jotta
-- esine-extension tietää, mihin karttaan poiminnat kirjataan.
local currentMap

--------------------------------------------------------------------------------------
-- Paikalliset funktiot

-- Etsitään ensimmäinen vapaa slot. Palautetaan sen merkkijonoavain tai nil.
local function firstFreeSlot()
	for slotIndex = 1, inventory.slotCount do
		local key = tostring( slotIndex )
		if not inventory.slots[key] then
			return key
		end
	end
	return nil
end

--------------------------------------------------------------------------------------
-- Julkiset funktiot

-- Kerrotaan, mitä karttaa parhaillaan rakennetaan.
function inventory.setMap( mapName )
	currentMap = mapName
	collected[mapName] = collected[mapName] or {}
end


-- Lisätään esine ensimmäiseen vapaaseen slotiin. Palautetaan true, jos esine mahtui
-- reppuun, ja false, jos kaikki slotit olivat täynnä. Näin kutsuja voi jättää esineen
-- kartalle, kun sille ei ole tilaa.
function inventory.add( itemId )
	local key = firstFreeSlot()
	if key then
		inventory.slots[key] = itemId
		return true
	end
	return false
end


-- Lisätään repun aloitusesineet: kaksi sekalaista esinettä, joilla ei ole pelissä
-- tehtävää. Ne näyttävät heti, miten reppu ja esineiden järjestely toimivat.
function inventory.addStartingItems()
	inventory.add( "coins" )
	inventory.add( "torch" )
end


-- Palautetaan annetun slotin esine (tai nil, jos slot on tyhjä).
function inventory.getSlot( slotIndex )
	return inventory.slots[tostring( slotIndex )]
end


-- Siirretään esine slotista toiseen. Jos kohdeslot on varattu, esineet vaihtavat
-- slotteja keskenään. Inventoryn käyttöliittymä kutsuu tätä esineitä järjestellessä.
function inventory.move( fromSlot, toSlot )
	local fromKey = tostring( fromSlot )
	local toKey = tostring( toSlot )
	inventory.slots[fromKey], inventory.slots[toKey] = inventory.slots[toKey], inventory.slots[fromKey]
end


-- Kerrotaan, onko repussa annettu esine.
function inventory.has( itemId )
	for slotIndex = 1, inventory.slotCount do
		if inventory.slots[tostring( slotIndex )] == itemId then
			return true
		end
	end
	return false
end


-- Poistetaan esine repusta, esim. kun se toimitetaan NPC:lle. Slot jää tyhjäksi.
function inventory.remove( itemId )
	for slotIndex = 1, inventory.slotCount do
		local key = tostring( slotIndex )
		if inventory.slots[key] == itemId then
			inventory.slots[key] = nil
			return
		end
	end
end


-- Merkitään nykyisen kartan objekti poimituksi.
function inventory.markCollected( objectName )
	collected[currentMap][objectName] = true
end


-- Kerrotaan, onko nykyisen kartan objekti jo poimittu.
function inventory.isCollected( objectName )
	return collected[currentMap] and collected[currentMap][objectName] == true
end

--------------------------------------------------------------------------------------

return inventory
