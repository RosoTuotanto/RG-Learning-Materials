-- loadsave-moduulin testiskripti. Ajaa pelin oikean scripts/loadsave.lua-moduulin
-- pienillä Solar2D-stubeilla (muistinvarainen tiedostojärjestelmä + yksinkertainen JSON)
-- ja tarkistaa tallennuksen ja latauksen kestävyyden: tallennuksen ja latauksen round tripin,
-- rikkinäisen tiedoston (palautuu nil kaatumatta), puuttuvan tiedoston, poiston sekä
-- pelitilan (versio 13) tallennusmuodon round tripin.
--
-- Käyttö:  lua5.1 verify_loadsave.lua [versiokansio]
--   [versiokansio] = polku versiokansioon (oletus: ../versio-15). Moduuli on sama versioissa 12-15.

------------------------------------------------------------------------------------
-- Muistinvarainen tiedostojärjestelmä ja Solar2D-stubit.

local projectDir = arg[1] or "../versio-15"

-- Polku -> tiedoston sisältö. Kaikki io-operaatiot kohdistuvat tähän tauluun.
local files = {}

system = {
	DocumentsDirectory = "docs",
	pathForFile = function( name, directory )
		return ( directory or "docs" ) .. "/" .. name
	end,
}

io = { -- luacheck: ignore io (stubi korvaa io-kirjaston muistinvaraisella versiolla)
	open = function( path, mode )
		if mode == "w" then
			return {
				write = function( _, data ) files[path] = data end,
				close = function() end,
			}
		else
			if files[path] == nil then
				return nil, "No such file or directory"
			end
			local contents = files[path]
			return {
				read = function() return contents end,
				close = function() end,
			}
		end
	end,
	close = function() end,
}

-- loadsave.delete kutsuu os.remove:a. Ohjataan se muistinvaraiseen taluun.
os.remove = function( path ) -- luacheck: ignore os (stubi ohjaa poiston muistiin)
	files[path] = nil
	return true
end

------------------------------------------------------------------------------------
-- Yksinkertainen JSON-stubi. Serialisoi taulun Lua-literaaliksi ja purkaa sen
-- loadstring:llä. Riittää loadsave-moduulin testaamiseen: se käyttää json-moduulia
-- läpinäkyvänä serialisoijana. Rikkinäinen sisältö aiheuttaa virheen, jonka
-- loadsave.load nappaa pcall:lla.

local function serialize( value )
	local valueType = type( value )
	if valueType == "string" then
		return string.format( "%q", value )
	elseif valueType == "number" or valueType == "boolean" then
		return tostring( value )
	elseif valueType == "table" then
		local length = #value
		local count = 0
		for _ in pairs( value ) do count = count + 1 end

		if count == length and length > 0 then
			local parts = {}
			for i = 1, length do
				parts[i] = serialize( value[i] )
			end
			return "{" .. table.concat( parts, "," ) .. "}"
		end

		local parts = {}
		for key, item in pairs( value ) do
			parts[#parts+1] = "[" .. serialize( key ) .. "]=" .. serialize( item )
		end
		return "{" .. table.concat( parts, "," ) .. "}"
	end
	error( "cannot serialize " .. valueType )
end

package.loaded["json"] = {
	encode = function( data ) return serialize( data ) end,
	prettify = function( text ) return text end,
	decode = function( text )
		local chunk = loadstring( "return " .. text )
		if not chunk then
			error( "invalid JSON" )
		end
		return chunk()
	end,
}

package.path = projectDir .. "/?.lua;" .. package.path

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

-- Deep equal: verrataan kahta arvoa, taulut rekursiivisesti.
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

local loadsave = require( "scripts.loadsave" )

print( "== loadsave-testi (" .. projectDir .. ") ==" )

-- 1. Tallennuksen ja latauksen round trip: sama data palautuu ennallaan.
local simple = { mapName = "village", coins = 3, cleared = true }
check( loadsave.save( simple, "simple.json" ) == true, "save palauttaa true onnistuessaan" )
check( deepEqual( loadsave.load( "simple.json" ), simple ), "tallennuksen ja latauksen round trip palauttaa saman datan" )

-- 2. Puuttuva tiedosto palautuu nil:nä ilman kaatumista.
check( loadsave.load( "eiOle.json" ) == nil, "puuttuva tiedosto palauttaa nil" )

-- 3. Rikkinäinen tiedosto palautuu nil:nä ilman kaatumista.
files[system.pathForFile( "corrupt.json", system.DocumentsDirectory )] = "{ tämä ei ole kelvollista"
check( loadsave.load( "corrupt.json" ) == nil, "rikkinäinen tiedosto palauttaa nil kaatumatta" )

-- 4. delete poistaa tallennuksen: latauksen jälkeen ei enää mitään.
loadsave.save( simple, "poisto.json" )
check( loadsave.load( "poisto.json" ) ~= nil, "delete: tallennus on olemassa ennen poistoa" )
loadsave.delete( "poisto.json" )
check( loadsave.load( "poisto.json" ) == nil, "delete poistaa tallennuksen" )

-- 5. Pelitilan (versio 13) tallennusmuoto säilyy round tripissä ennallaan.
-- inventory on repun ruudukko, joka tallennetaan merkkijonoavaimin (game.lua kirjoittaa
-- inventory.slots-taulun suoraan). Paikka 2 jätetään tyhjäksi, jotta harva paikkataulu
-- (aukko paikkojen 1 ja 3 välissä) testataan: merkkijonoavaimin se säilyy JSON-round tripissä ehjänä.
local gameState = {
	mapName = "sideroad",
	playerX = 128.5,
	playerY = 640,
	facing = { x = 0, y = 1 },
	inventory = { ["1"] = "note", ["3"] = "book_red" },
	collected = { village = { book = true }, sideroad = { bottle = true } },
}
loadsave.save( gameState, "gamesave.json" )
check( deepEqual( loadsave.load( "gamesave.json" ), gameState ), "pelitilan tallennusmuoto säilyy round tripissä (versio 13)" )

-- 6. Kelvollinen JSON, joka ei dekoodaudu taulukoksi (pelkkä luku): type-tarkistus
-- palauttaa nil kaatumatta, vaikka pcall itse onnistuu.
files[system.pathForFile( "number.json", system.DocumentsDirectory )] = "42"
check( loadsave.load( "number.json" ) == nil, "ei-taulukoksi purkautuva JSON (pelkkä luku) palauttaa nil" )

-- 7. delete jo puuttuvaan tiedostoon: loadsave.delete sivuuttaa os.remove:n paluuarvon,
-- joten kutsu on hiljainen tyhjä operaatio eikä kaadu. Lataus pysyy nil:nä.
local deleteOk = pcall( loadsave.delete, "eiOle.json" )
check( deleteOk, "delete puuttuvaan tiedostoon ei kaadu (paluuarvo sivuutetaan)" )
check( loadsave.load( "eiOle.json" ) == nil, "puuttuva tiedosto pysyy nil:nä poiston jälkeen" )

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI" )
	os.exit( 1 )
end
