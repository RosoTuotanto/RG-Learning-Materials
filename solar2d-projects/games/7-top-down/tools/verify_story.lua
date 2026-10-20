-- Tarinan testiskripti. Ajaa pelin oikean tarinatiedoston oikean, vendoroidun
-- Weaver-tarinamoottorin ja pelin dialogimoduulin läpi pienillä Solar2D-stubeilla ja
-- tarkistaa tehtäväketjun ehtologiikan sekä omien <<...>>-komentojen palautumisen.
--
-- Käyttö:  lua5.1 verify_story.lua <versiokansio> <vaihe>
--   <versiokansio> = polku versiokansioon (esim. ../versio-9)
--   <vaihe>        = versionumero; assertit ajetaan vaiheittain: 8 Weaver-perusdialogi
--                    ilman automaattista tallennusta, 9 tehtäväketju, 10 viestikomennot,
--                    11 portin lukituksen lukema tehtävätila, 13 tarinan tallennus ja
--                    lataus (myös vanhan tallennuksen täydennys), 15 taustahahmojen
--                    satunnaisrepliikki (npcTausta).

------------------------------------------------------------------------------------
-- Pieni JSON-dekooderi ja -enkooderi. Weaver lukee tarinan ja tallennuksen json.decode:lla
-- ja kirjoittaa tallennuksen json.encode:lla, joten stubataan moduuli "json" näillä.

local function decodeJSON( source )
	local pos = 1

	local parseValue

	local function skipSpace()
		local _, endPos = source:find( "^[ \t\r\n]*", pos )
		pos = endPos + 1
	end

	local function parseString()
		pos = pos + 1 -- ohita avaava lainausmerkki
		local buffer = {}
		while true do
			local char = source:sub( pos, pos )
			if char == "" then
				error( "verify_story: unterminated string in JSON" )
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
					local code = tonumber( source:sub( pos + 2, pos + 5 ), 16 )
					-- Koodaa Basic Multilingual Plane -merkki UTF-8:ksi.
					if code < 0x80 then
						buffer[#buffer+1] = string.char( code )
					elseif code < 0x800 then
						buffer[#buffer+1] = string.char( 0xC0 + math.floor( code / 0x40 ), 0x80 + code % 0x40 )
					else
						buffer[#buffer+1] = string.char(
							0xE0 + math.floor( code / 0x1000 ),
							0x80 + math.floor( code / 0x40 ) % 0x40,
							0x80 + code % 0x40 )
					end
					pos = pos + 6
				else
					error( "verify_story: bad escape \\" .. escape )
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


local function encodeJSON( value )
	local valueType = type( value )

	if valueType == "table" then
		local isArray = #value > 0 or next( value ) == nil
		local parts = {}

		if isArray then
			for index = 1, #value do
				parts[#parts+1] = encodeJSON( value[index] )
			end
			return "[" .. table.concat( parts, "," ) .. "]"
		end

		for key, entry in pairs( value ) do
			parts[#parts+1] = encodeJSON( tostring( key ) ) .. ":" .. encodeJSON( entry )
		end
		return "{" .. table.concat( parts, "," ) .. "}"

	elseif valueType == "string" then
		local escaped = value:gsub( '[%c"\\]', function( char )
			return string.format( "\\u%04x", char:byte() )
		end )
		return '"' .. escaped .. '"'

	elseif valueType == "number" or valueType == "boolean" then
		return tostring( value )
	end

	return "null"
end

------------------------------------------------------------------------------------
-- Solar2D-stubit, jotta Weaver ja moduulit latautuvat lua5.1:ssä.

local projectDir = arg[1]
local stage = tonumber( arg[2] )

if not projectDir or not stage then
	print( "Käyttö: lua5.1 verify_story.lua <versiokansio> <vaihe>" )
	os.exit( 1 )
end

package.loaded["json"] = {
	decode = function( text ) return decodeJSON( text ) end,
	encode = function( value ) return encodeJSON( value ) end,
}

-- Solar2D lisää tavalliseen table-kirjastoon table.copy-funktion, joka kopioi vain taulukon
-- numeroavaimet (platform/resources/init.lua). Stubi toimii samoin, jottei testi peitä
-- nimettyjen kenttien katoamista. rawset välttää luacheckin "setting undefined field" -varoituksen.
rawset( table, "copy", function( ... )
	local result = {}
	local args = { ... }
	for a = 1, #args do
		for index = 1, #args[a] do result[#result+1] = args[a][index] end
	end
	return result
end )

-- Weaverin tallennukset kirjoitetaan omaan väliaikaiskansioon, jottei rinnakkainen ajo
-- tai edellinen ajo sotke tuloksia.
local documentsDir = os.tmpname()
os.remove( documentsDir )
os.execute( "mkdir -p '" .. documentsDir .. "'" )

system = {
	ResourceDirectory = projectDir,
	DocumentsDirectory = documentsDir,
	pathForFile = function( name, directory )
		return ( directory or projectDir ) .. "/" .. name
	end,
	getInfo = function() return "simulator" end,
}

-- Minimaaliset stubit näytön moduuleille (harness ei piirrä mitään).
display = setmetatable( {
	screenOriginX = 0, screenOriginY = 0,
	contentWidth = 640, contentHeight = 960,
	actualContentWidth = 640, actualContentHeight = 960,
	contentCenterX = 320, contentCenterY = 480,
	safeScreenOriginX = 0, safeScreenOriginY = 0,
	safeActualContentWidth = 640, safeActualContentHeight = 960,
	HiddenStatusBar = 0,
}, { __index = function() return function() end end } )

Runtime = { addEventListener = function() end, removeEventListener = function() end }

package.path = projectDir .. "/?.lua;" .. package.path

------------------------------------------------------------------------------------
-- Apufunktiot

local storyName = "Topdown seikkailu"
local storySource = "data/Topdown seikkailu.json"
local globalKey = "WEAVERx" .. storyName:gsub( "%s+", "" )

local failures = 0

local function check( condition, message )
	if condition then
		print( "  PASS  " .. message )
	else
		failures = failures + 1
		print( "  FAIL  " .. message )
	end
end

local function quest()
	return _G[globalKey].saveData.quest
end

-- Palauttaa passagen kaiken tekstin yhtenä merkkijonona.
local function textOf( line )
	local parts = {}
	for i = 1, #line do
		if line[i][1] == "text" then parts[#parts+1] = line[i][2] end
	end
	return table.concat( parts, " " )
end

-- Palauttaa passagen vaihtoehtojen tekstit yhtenä merkkijonona.
local function linksOf( line )
	local parts = {}
	for i = 1, #line do
		if line[i][1] == "link" then parts[#parts+1] = line[i][2] end
	end
	return table.concat( parts, " | " )
end

-- Etsii passagesta annetulla nimellä olevan oman komennon (line[i][1]).
local function findCommand( line, name )
	for i = 1, #line do
		if line[i][1] == name then return line[i] end
	end
	return nil
end

local function writeFile( path, contents )
	local file = assert( io.open( path, "w" ) )
	file:write( contents )
	file:close()
end

local function fileExists( path )
	local file = io.open( path, "r" )
	if file then file:close() end
	return file ~= nil
end

local function readSource( relativePath )
	local file = assert( io.open( projectDir .. "/" .. relativePath, "r" ) )
	local contents = file:read( "*a" )
	file:close()
	return contents
end

local weaverSavePath = documentsDir .. "/weaverSave.json"

local weaver = require( "scripts.spyricStoryWeaver" )
local dialogue = require( "scripts.dialogue" )

------------------------------------------------------------------------------------
-- Vaihe 8: perusdialogi (teksti + vaihtoehdot), ei tehtävätilaa.

print( "== Vaihe " .. stage .. ": " .. storyName .. " ==" )

weaver.initStory( { name = storyName, source = storySource } )

local house = weaver.getNode( "npcHouse", storyName )
check( type( house ) == "table" and #textOf( house ) > 0, "npcHouse palauttaa tekstiä" )
check( textOf( house ):find( "Elder Wren:" ) ~= nil, "talon asukas esittäytyy kylän vanhimpana (Elder Wren)" )

local beach = weaver.getNode( "npcBeach", storyName )
check( type( beach ) == "table" and #textOf( beach ) > 0, "npcBeach palauttaa tekstiä" )

if stage == 8 then
	check( linksOf( house ):find( "Ask about the village" ) ~= nil, "npcHouse tarjoaa vaihtoehdon Ask about the village" )
	check( linksOf( house ):find( "Say goodbye" ) ~= nil, "npcHouse tarjoaa vaihtoehdon Say goodbye" )
	check( #textOf( weaver.getNode( "npcHouseKyla", storyName ) ) > 0, "npcHouseKyla sisältää tekstiä" )
end

-- Weaver ei tallenna itsestään, ja tarina ladataan kerran pelin käynnistyessä. Jos pelinäkymä
-- lataisi tarinan jokaisen kartan rakentamisen yhteydessä, tehtävätila nollautuisi kentän vaihdossa.
dialogue.init()
weaver.getNode( "npcHouse", storyName )
weaver.getNode( "npcBeach", storyName )
check( not fileExists( weaverSavePath ), "Weaver ei kirjoita tallennusta ilman save-kutsua" )
check( readSource( "main.lua" ):find( "dialogue.init()", 1, true ) ~= nil, "main.lua lataa tarinan kerran pelin käynnistyessä" )
check( readSource( "scenes/game.lua" ):find( "dialogue.init(", 1, true ) == nil, "pelinäkymä ei lataa tarinaa uudelleen kartan rakentamisen yhteydessä" )

------------------------------------------------------------------------------------
-- Vaihe 9: tehtäväketju vanhin -> ranta -> raportti vanhimmalle.

if stage >= 9 then
	weaver.clearCache()
	weaver.initStory( { name = storyName, source = storySource } )
	check( quest() == 0, "uusi peli alkaa tilasta quest == 0" )

	local intro = weaver.getNode( "intro", storyName )
	check( textOf( intro ):find( "elder" ) ~= nil, "intro ohjaa kylän vanhimman luo" )
	check( quest() == 0, "intro ei muuta questia" )

	local beachEarly = weaver.getNode( "npcBeach", storyName )
	check( quest() == 0, "npcBeach ei muuta questia ennen tehtävää" )
	check( textOf( beachEarly ) == "Stranger: Hello there. The sea breeze is lovely today.", "rannan kulkija vain tervehtii ennen tehtävää" )

	local mission = weaver.getNode( "npcHouse", storyName )
	check( quest() == 1, "vanhin antaa tehtävän: quest == 1" )
	check( textOf( mission ):find( "south gate" ) ~= nil, "tehtävänanto kertoo, mistä rantatie alkaa" )
	check( linksOf( mission ) == "Who is the stranger? | I'll go now", "tehtävänannon vaihtoehdot ovat Who is the stranger? ja I'll go now" )
	check( #textOf( weaver.getNode( "npcHouseMuukalainen", storyName ) ) > 0, "npcHouseMuukalainen sisältää tekstiä" )

	local reminder = weaver.getNode( "npcHouse", storyName )
	check( quest() == 1, "vanhimman muistutus ei muuta questia" )
	check( textOf( reminder ):find( "south gate" ) ~= nil, "muistutus kertoo, mistä rantatie alkaa" )
	check( linksOf( reminder ) == "", "muistutuksessa ei ole vaihtoehtoja" )

	local answer = weaver.getNode( "npcBeach", storyName )
	check( quest() == 2, "rannan kulkija vastaa: quest == 2" )
	check( textOf( answer ):find( "Marlow" ) ~= nil, "rannan kulkija kertoo nimensä (Marlow)" )

	if stage >= 10 then
		local giveNote = findCommand( answer, "annaViesti" )
		check( giveNote ~= nil and giveNote[1] == "annaViesti", "vastaus palauttaa <<annaViesti>>-komennon taulukkona" )
	else
		check( findCommand( answer, "annaViesti" ) == nil, "vaiheessa 9 vastauksessa ei ole vielä viestikomentoa" )
	end

	weaver.getNode( "npcBeach", storyName )
	check( quest() == 2, "rannan kulkijan muistutus ei muuta questia" )

	local report = weaver.getNode( "npcHouse", storyName )
	check( quest() == 3, "raportti vanhimmalle: quest == 3" )
	check( textOf( report ):find( "Marlow" ) ~= nil, "raportissa kerrotaan Marlow'sta" )

	if stage >= 10 then
		local deliverNote = findCommand( report, "toimitaViesti" )
		check( deliverNote ~= nil and deliverNote[1] == "toimitaViesti", "raportti palauttaa <<toimitaViesti>>-komennon taulukkona" )
	end

	local thanks = weaver.getNode( "npcHouse", storyName )
	check( quest() == 3, "kiitos ei muuta questia" )
	check( linksOf( thanks ):find( "Ask about the village" ) ~= nil, "tehtävän jälkeen vanhimmalta voi kysyä kylästä" )

	if stage >= 11 then
		check( dialogue.getFlag( "quest" ) == quest(), "dialogue.getFlag lukee saman quest-arvon, jota lukittu portti käyttää" )
	end

end

------------------------------------------------------------------------------------
-- Vaihe 13: tarinan tila tallennetaan ja ladataan vain pyydettäessä, samalla hetkellä kuin
-- pelitila. Uusi peli aloittaa tarinan alusta.

if stage >= 13 then
	weaver.clearCache()
	os.remove( weaverSavePath )
	dialogue.init()
	check( weaver.load( storyName ) == false, "lataus ilman tallennusta palauttaa false" )
	check( quest() == 0, "lataus ilman tallennusta jättää tarinan alkutilaan" )

	weaver.getNode( "npcHouse", storyName )
	dialogue.save()
	check( fileExists( weaverSavePath ), "dialogue.save kirjoittaa Weaverin tallennuksen" )

	weaver.getNode( "npcBeach", storyName )
	check( quest() == 2, "tallennuksen jälkeinen eteneminen: quest == 2" )

	dialogue.init()
	check( quest() == 0, "uusi peli (dialogue.init) aloittaa tarinan alusta tallennuksesta huolimatta" )

	dialogue.load()
	check( quest() == 1, "Continue (dialogue.load) palauttaa tallennushetken tehtävätilan" )
	check( _G[globalKey].saveData.node["npcHouse"].visits == 1, "Continue palauttaa passagejen käyntimäärät" )
	check( dialogue.getFlag( "quest" ) == 1, "lukittu portti lukee ladatun tehtävätilan" )

	-- Vanhan tallennuksen täydennys: aiemman version tallennuksesta puuttuvat uudet
	-- passaget ja muuttujat. Weaverin load antaa niille oletusarvot, jottei Weaver kaadu.
	writeFile( weaverSavePath, encodeJSON( {
		node = {
			npcHouse = { visits = 2, link = true },
			npcBeach = { visits = 1, link = true },
		},
		previousNodes = { "npcHouse" },
	} ) )
	dialogue.init()
	dialogue.load()

	local ok = pcall( weaver.getNode, "intro", storyName )
	check( ok, "vanha tallennus: uusi passage (intro) avautuu kaatumatta" )
	check( quest() == 0, "vanha tallennus: puuttuva quest-muuttuja saa oletusarvon 0" )
	check( _G[globalKey].saveData.node["npcHouse"].visits == 2, "vanha tallennus: olemassa olevat käyntimäärät säilyvät" )
	check( _G[globalKey].saveData.node["variables"] == nil, "vanha tallennus: asetuspassagea ei lisätä passageiksi" )
end

------------------------------------------------------------------------------------
-- npcTausta-taustarepliikki (vain jos node on olemassa).
-- Weaverin (either:) pilkkoo sulkeiden sisällön naiivisti pilkuilla, joten
-- yhdessäkään vaihtoehdossa EI SAA olla pilkkua. Arvotaan repliikki ~200 kertaa ja
-- vaaditaan, että jokainen tulos on täsmälleen yksi odotetuista puhtaista merkkijonoista.

if _G[globalKey].storyData["npcTausta"] then
	local expected = {
		["Villager: What a beautiful day."] = true,
		["Villager: The fish are biting today."] = true,
		["Villager: Greetings stranger."] = true,
		["Villager: Nice to see a new face in Saltford."] = true,
	}

	local seen = {}
	local allValid = true
	local sawQuote = false
	for _ = 1, 200 do
		local text = textOf( weaver.getNode( "npcTausta", storyName ) )
		seen[text] = true
		if not expected[text] then allValid = false end
		if text:find( '"', 1, true ) then sawQuote = true end
	end

	local distinct = 0
	for _ in pairs( seen ) do distinct = distinct + 1 end

	check( allValid, "npcTausta: jokainen 200 arvonnasta on yksi odotetuista repliikeistä" )
	check( not sawQuote, "npcTausta: arvonnoissa ei esiinny lainausmerkkejä (ei pilkkusirpaleita)" )
	check( distinct >= 2, "npcTausta: 200 arvonnasta saadaan useampi eri repliikki" )
elseif stage >= 15 then
	check( false, "npcTausta-passage puuttuu vaiheesta 15" )
end

------------------------------------------------------------------------------------
-- Weaverin tarinasyntaksi, jota uudet tarinat voivat käyttää: //-kommenttirivit ja alaviivat
-- $- ja _-muuttujien nimissä, myös samassa ehdossa. Erillinen testitarina kirjoitetaan
-- väliaikaiskansioon, joten tarkistus ajetaan jokaisessa vaiheessa.

local syntaxSource = "verify-syntax.json"
writeFile( documentsDir .. "/" .. syntaxSource, encodeJSON( {
	{ title = "variables", tags = "options", body = "{ \"has_key\": false }" },
	{ title = "syntax", body = table.concat( {
		"// Tämä rivi on kommentti.",
		"# Niin on tämäkin.",
		"<<set $has_key = true>>",
		"<<set _door_open = 1>>",
		"<<if $has_key == true and _door_open == 1>>",
		"Avain: $has_key, ovi: _door_open",
		"<<else>>",
		"Ehto ei toteutunut.",
		"<<end>>",
	}, "\n" ) },
} ) )

local pathForFile = system.pathForFile
system.pathForFile = function( name, directory )
	if name == syntaxSource then return documentsDir .. "/" .. name end
	return pathForFile( name, directory )
end
weaver.initStory( { name = "Syntaksi", source = syntaxSource } )
system.pathForFile = pathForFile

local syntaxOk, syntax = pcall( weaver.getNode, "syntax", "Syntaksi" )
check( syntaxOk, "Weaver: testitarina avautuu kaatumatta" )
local syntaxText = type( syntax ) == "table" and textOf( syntax ) or ""
check( syntaxText ~= "" and not syntaxText:find( "kommentti" ) and not syntaxText:find( "tämäkin" ), "Weaver: //- ja #-kommenttirivit eivät näy tekstinä" )
check( syntaxText == "Avain: true, ovi: 1", "Weaver: alaviiva toimii $- ja _-muuttujien nimissä ja samassa ehdossa" )
check( _G["WEAVERxSyntaksi"].saveData.has_key == true, "Weaver: <<set $has_key = true>> tallentaa muuttujan has_key" )
weaver.removeFromCache( "Syntaksi" )

os.remove( documentsDir .. "/" .. syntaxSource )
os.remove( documentsDir .. "/weaverSave.json" )
os.remove( documentsDir )

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI (" .. stage .. ")" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI (" .. stage .. ")" )
	os.exit( 1 )
end
