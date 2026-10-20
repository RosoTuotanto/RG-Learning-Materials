-- Inventoryn testiskripti. Ajaa pelin oikean scripts/inventory.lua-moduulin
-- (ruudukkomalli) ja maps/extensions/item.lua-extensionin pienillä stubeilla lua5.1:ssä ja
-- tarkistaa esinepaikkojen logiikan: lisäys ensimmäiseen vapaaseen paikkaan, has/remove
-- tunnisteella, siirto ja vaihto paikkojen välillä, täysi reppu, aloitusesineet sekä
-- esinepaikkojen json.encode/json.decode -round tripin, joka todistaa ettei serialisointi
-- tarvitse harvaa taulukkoa (merkkijonoavaimet säilyvät ehjinä). Vaiheittain lisäksi:
-- 10 poimittu esine ilmestyy takaisin, kun kartta rakennetaan uudelleen (oppitunnin
-- ongelma), 11 poimintarekisteri estää sen, 13 reset tyhjentää ja restore palauttaa tilan.
--
-- Käyttö:  lua5.1 verify_inventory.lua [versiokansio] [vaihe]
--   [versiokansio] = polku versiokansioon (oletus: ../versio-15)
--   [vaihe]        = versionumero (oletus: 15); inventory on olemassa versiosta 10 alkaen.

------------------------------------------------------------------------------------
-- Pieni mutta uskollinen JSON-koodekki. Encode tunnistaa tiiviin 1..n -taulukon
-- (jolloin siitä tulee JSON-taulukko) ja koodaa kaiken muun JSON-objektiksi
-- merkkijonoavaimin, aivan kuten Solar2D:n dkjson-pohjainen json.encode. Sama
-- serialisointitapa, jota loadsave.save käyttää pelitilaa tallentaessaan.

local function encodeString( str )
	return '"' .. str:gsub( '[%z\1-\31\\"]', function( char )
		local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
		return escapes[char] or string.format( "\\u%04x", char:byte() )
	end ) .. '"'
end

local function encodeJSON( value )
	local valueType = type( value )
	if valueType == "string" then
		return encodeString( value )
	elseif valueType == "number" or valueType == "boolean" then
		return tostring( value )
	elseif valueType == "table" then
		local count = 0
		for _ in pairs( value ) do count = count + 1 end

		-- Tiivis taulukko vain, jos kokonaislukuavaimet 1..count ovat kaikki olemassa.
		local isArray = count > 0
		for index = 1, count do
			if value[index] == nil then
				isArray = false
				break
			end
		end

		if isArray then
			local parts = {}
			for index = 1, count do
				parts[index] = encodeJSON( value[index] )
			end
			return "[" .. table.concat( parts, "," ) .. "]"
		end

		local parts = {}
		for key, item in pairs( value ) do
			parts[#parts+1] = encodeString( tostring( key ) ) .. ":" .. encodeJSON( item )
		end
		return "{" .. table.concat( parts, "," ) .. "}"
	end
	error( "cannot encode " .. valueType )
end

local function decodeJSON( source )
	local pos = 1
	local parseValue

	local function skipSpace()
		local _, endPos = source:find( "^[ \t\r\n]*", pos )
		pos = endPos + 1
	end

	local function parseString()
		pos = pos + 1
		local buffer = {}
		while true do
			local char = source:sub( pos, pos )
			if char == "" then
				error( "unterminated string" )
			elseif char == '"' then
				pos = pos + 1
				break
			elseif char == "\\" then
				local escape = source:sub( pos + 1, pos + 1 )
				local simple = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
					b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
				if simple[escape] then
					buffer[#buffer+1] = simple[escape]
					pos = pos + 2
				elseif escape == "u" then
					buffer[#buffer+1] = string.char( tonumber( source:sub( pos + 2, pos + 5 ), 16 ) % 256 )
					pos = pos + 6
				else
					error( "bad escape" )
				end
			else
				buffer[#buffer+1] = char
				pos = pos + 1
			end
		end
		return table.concat( buffer )
	end

	local function parseObject()
		pos = pos + 1
		local result = {}
		skipSpace()
		if source:sub( pos, pos ) == "}" then pos = pos + 1 return result end
		while true do
			skipSpace()
			local key = parseString()
			skipSpace()
			pos = pos + 1 -- ohita kaksoispiste
			result[key] = parseValue()
			skipSpace()
			local char = source:sub( pos, pos )
			pos = pos + 1
			if char == "}" then break end
		end
		return result
	end

	local function parseArray()
		pos = pos + 1
		local result = {}
		skipSpace()
		if source:sub( pos, pos ) == "]" then pos = pos + 1 return result end
		while true do
			result[#result+1] = parseValue()
			skipSpace()
			local char = source:sub( pos, pos )
			pos = pos + 1
			if char == "]" then break end
		end
		return result
	end

	function parseValue()
		skipSpace()
		local char = source:sub( pos, pos )
		if char == '"' then
			return parseString()
		elseif char == "{" then
			return parseObject()
		elseif char == "[" then
			return parseArray()
		elseif char == "t" then
			pos = pos + 4 return true
		elseif char == "f" then
			pos = pos + 5 return false
		elseif char == "n" then
			pos = pos + 4 return nil
		else
			local numberText = source:match( "^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos )
			pos = pos + #numberText
			return tonumber( numberText )
		end
	end

	return parseValue()
end

------------------------------------------------------------------------------------
-- Stubit esine-extensionille: display-objektit, image sheet ja fysiikka.

local removedObjects = {}

display = {
	newImageRect = function( parent, _, frame )
		local object = { parent = parent, frame = frame }
		return object
	end,
	remove = function( object )
		if object then
			removedObjects[object] = true
		end
	end,
}

graphics = {
	newImageSheet = function()
		return {}
	end,
}

physics = {
	addBody = function() end,
}

------------------------------------------------------------------------------------
-- Testiajo ja assertit.

local projectDir = arg[1] or "../versio-15"
local stage = tonumber( arg[2] ) or 15
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

local function deepEqual( a, b )
	if type( a ) ~= type( b ) then return false end
	if type( a ) ~= "table" then return a == b end
	for key, value in pairs( a ) do
		if not deepEqual( value, b[key] ) then return false end
	end
	for key in pairs( b ) do
		if a[key] == nil then return false end
	end
	return true
end

-- Ladataan moduuli aina puhtaana, jotta jokainen osio alkaa tyhjästä repusta myös
-- versioissa, joissa reset-funktiota ei vielä ole.
local function freshInventory()
	package.loaded["scripts.inventory"] = nil
	package.loaded["maps.extensions.item"] = nil
	return require( "scripts.inventory" )
end

print( "== inventory-testi (" .. projectDir .. ", vaihe " .. stage .. ") ==" )

-- 1. add täyttää ensimmäisen vapaan paikan järjestyksessä ja palauttaa onnistumistiedon.
local inventory = freshInventory()
check( inventory.add( "note" ) == true, "add: onnistunut lisäys palauttaa true" )
inventory.add( "book_red" )
check( inventory.getSlot( 1 ) == "note", "add: ensimmäinen esine menee paikkaan 1" )
check( inventory.getSlot( 2 ) == "book_red", "add: toinen esine menee paikkaan 2" )
check( inventory.getSlot( 3 ) == nil, "add: käyttämätön paikka on tyhjä" )

-- 2. has kertoo esineen olemassaolon tunnisteella.
check( inventory.has( "note" ) == true, "has: repussa oleva esine löytyy" )
check( inventory.has( "map" ) == false, "has: puuttuva esine ei löydy" )

-- 3. remove tyhjentää oikean paikan tunnisteella.
inventory.remove( "note" )
check( inventory.getSlot( 1 ) == nil, "remove: esineen paikka tyhjenee" )
check( inventory.has( "note" ) == false, "remove: esine ei enää löydy" )
check( inventory.getSlot( 2 ) == "book_red", "remove: muut paikat säilyvät" )

-- 4. add täyttää nimenomaan ensimmäisen vapaan paikan (paikka 1 vapautui äsken).
inventory.add( "key" )
check( inventory.getSlot( 1 ) == "key", "add: esine menee ensimmäiseen vapaaseen paikkaan (1), ei jatkoksi" )

-- 5. move siirtää esineen tyhjään paikkaan ja vaihtaa esineet varatussa paikassa.
inventory = freshInventory()
inventory.add( "note" )     -- paikka 1
inventory.add( "book_red" ) -- paikka 2
inventory.move( 1, 5 )
check( inventory.getSlot( 1 ) == nil and inventory.getSlot( 5 ) == "note", "move: esine siirtyy tyhjään paikkaan" )
inventory.move( 5, 2 )
check( inventory.getSlot( 2 ) == "note" and inventory.getSlot( 5 ) == "book_red", "move: varattuun paikkaan siirto vaihtaa esineet" )

-- 6. add palauttaa false, kun reppu on täynnä, eikä muuta esinepaikkoja.
inventory = freshInventory()
for slotIndex = 1, inventory.slotCount do
	inventory.add( "item" .. slotIndex )
end
check( inventory.add( "ylimaarainen" ) == false, "add: täyteen reppuun lisäys palauttaa false" )

local unchanged = true
for slotIndex = 1, inventory.slotCount do
	if inventory.getSlot( slotIndex ) ~= "item" .. slotIndex then
		unchanged = false
	end
end
check( unchanged, "add: täyteen reppuun lisäys ei muuta esinepaikkoja" )
check( inventory.has( "ylimaarainen" ) == false, "add: hylätty esine ei päädy reppuun" )

-- 7. JSON-round trip todistaa, ettei harvaa taulukkoa tarvita. Esinepaikat serialisoidaan
-- samalla tavalla kuin loadsave.save tekee (json.encode( inventory.slots )).
-- Rakennetaan tarkoituksella harva tilanne: paikka 2 jää tyhjäksi paikkojen 1 ja 3 väliin.
inventory = freshInventory()
inventory.add( "a" )   -- paikka 1
inventory.add( "b" )   -- paikka 2
inventory.add( "c" )   -- paikka 3
inventory.remove( "b" ) -- jää { ["1"]="a", ["3"]="c" }

local encoded = encodeJSON( inventory.slots )
local decoded = decodeJSON( encoded )
check( encoded:sub( 1, 1 ) == "{", "json: esinepaikat serialisoituvat JSON-objektiksi, ei taulukoksi" )
check( encoded:find( '"3":', 1, true ) ~= nil, "json: aukon jälkeinen paikka-avain säilyy objektissa" )
check( deepEqual( decoded, inventory.slots ), "json: harva esinepaikkataulu säilyy round tripissä (merkkijonoavaimet)" )

-- Täysi reppu (kaikki 8 paikkaa) pysyy objektina eikä romahda taulukoksi.
inventory = freshInventory()
for slotIndex = 1, inventory.slotCount do
	inventory.add( "item" .. slotIndex )
end
local encodedFull = encodeJSON( inventory.slots )
local decodedFull = decodeJSON( encodedFull )
check( encodedFull:sub( 1, 1 ) == "{", "json: täysi reppu serialisoituu objektiksi (merkkijonoavaimet, ei taulukko)" )
check( deepEqual( decodedFull, inventory.slots ), "json: täysi reppu säilyy round tripissä" )

-- Vastaesimerkki: harva KOKONAISLUKUavaiminen taulu ei säily round tripissä ehjänä, mikä on juuri
-- se ansa, jonka merkkijonoavaimet välttävät. Avaimet muuttuvat round tripissä merkkijonoiksi.
local sparseIntegerKeyed = { [1] = "a", [3] = "c" }
check( not deepEqual( decodeJSON( encodeJSON( sparseIntegerKeyed ) ), sparseIntegerKeyed ),
	"json: harva kokonaislukuavaiminen taulu EI säily round tripissä ehjänä (siksi käytetään merkkijonoavaimia)" )

-- 8. Aloitusesineet: kaksi sekalaista esinettä täyttää paikat 1 ja 2, ja molemmat
-- löytyvät esineluettelosta (data.items), ja jokaisella on oma frame image sheetissä.
inventory = freshInventory()
inventory.addStartingItems()
check( inventory.getSlot( 1 ) ~= nil and inventory.getSlot( 2 ) ~= nil, "aloitusesineet: paikat 1 ja 2 täyttyvät" )
check( inventory.getSlot( 1 ) ~= inventory.getSlot( 2 ), "aloitusesineet: esineet ovat eri esineitä" )

local items = require( "data.items" )
local firstItem = items[inventory.getSlot( 1 )]
local secondItem = items[inventory.getSlot( 2 )]
check( type( firstItem ) == "table" and type( firstItem.frame ) == "number", "aloitusesineet: ensimmäinen esine löytyy esineluettelosta" )
check( type( secondItem ) == "table" and type( secondItem.frame ) == "number", "aloitusesineet: toinen esine löytyy esineluettelosta" )

-- 9. Esine-extension: kartta rakennetaan jokaisella saapumisella uudelleen JSONista.
-- Vaiheessa 10 poimittu esine ilmestyy takaisin, vaiheesta 11 alkaen rekisteri estää sen.
inventory = freshInventory()
local itemExtension = require( "maps.extensions.item" )
local mapLayer = {}

local function buildBook()
	if inventory.setMap then
		inventory.setMap( "village" )
	end
	return itemExtension.new( { parent = mapLayer, x = 448, y = 512, frame = 2, item = "book_red", name = "book" } )
end

local book = buildBook()
check( type( book ) == "table" and book.type == "item", "esine-extension: kartan esine rakentuu" )
check( book and book:pickup() == true and inventory.has( "book_red" ), "esine-extension: poiminta lisää esineen reppuun" )
check( book and removedObjects[book] == true, "esine-extension: poimittu esine poistetaan kartalta" )

local rebuiltBook = buildBook()
if stage >= 11 then
	check( rebuiltBook == nil, "rekisteri: poimittu esine ei ilmesty takaisin, kun kartta rakennetaan uudelleen" )
else
	check( rebuiltBook ~= nil, "vaihe 10: poimittu esine ilmestyy takaisin (oppitunnin päättävä ongelma)" )
	check( inventory.setMap == nil and inventory.markCollected == nil, "vaihe 10: poimintarekisteriä ei vielä ole" )
end

-- Täysi reppu: poiminta epäonnistuu eikä esinettä merkitä poimituksi.
inventory = freshInventory()
itemExtension = require( "maps.extensions.item" )
for slotIndex = 1, inventory.slotCount do
	inventory.add( "item" .. slotIndex )
end
local fullBook = buildBook()
check( fullBook:pickup() == false and removedObjects[fullBook] == nil, "esine-extension: täyteen reppuun poiminta jättää esineen kartalle" )
if stage >= 11 then
	check( inventory.isCollected( "book" ) == false, "rekisteri: epäonnistunutta poimintaa ei merkitä poimituksi" )
end

-- 10. Rekisteri (vaihe 11+): poiminnat kirjataan nykyiselle kartalle.
if stage >= 11 then
	inventory = freshInventory()
	inventory.setMap( "village" )
	inventory.markCollected( "bookObject" )
	check( inventory.isCollected( "bookObject" ) == true, "markCollected/isCollected: poiminta kirjautuu" )
	check( inventory.isCollected( "muu" ) == false, "isCollected: kirjaamaton objekti ei ole poimittu" )
	inventory.setMap( "sideroad" )
	check( inventory.isCollected( "bookObject" ) == false, "isCollected: rekisteri on karttakohtainen" )
end

-- 11. reset ja restore (vaihe 13+): uusi peli tyhjentää, jatkaminen palauttaa.
if stage >= 13 then
	inventory = freshInventory()
	inventory.add( "note" )
	inventory.setMap( "village" )
	inventory.markCollected( "bookObject" )
	inventory.reset()
	check( inventory.getSlot( 1 ) == nil, "reset: paikat tyhjenevät" )
	check( next( inventory.getCollected() ) == nil, "reset: poimintarekisteri tyhjenee" )

	local savedSlots = { ["1"] = "note", ["4"] = "book_red" }
	local savedCollected = { village = { bookObject = true }, sideroad = { bottleObject = true } }
	inventory.restore( savedSlots, savedCollected )
	check( inventory.getSlot( 1 ) == "note" and inventory.getSlot( 4 ) == "book_red", "restore: paikat palautuvat" )
	check( deepEqual( inventory.getCollected(), savedCollected ), "restore: poimintarekisteri palautuu ennallaan" )
end

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI (" .. stage .. ")" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI (" .. stage .. ")" )
	os.exit( 1 )
end
