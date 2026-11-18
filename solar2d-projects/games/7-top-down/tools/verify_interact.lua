-- Vuorovaikutuksen kohdehaun testiskripti. Ajaa pelin oikean scenes/game.lua-scenen ja
-- maps/extensions-kansion hero-, npc- ja item-extensionit lua5.1:ssä pienillä Solar2D-stubeilla.
-- Kartta rakennetaan jokaiseen testiin uudelleen scene:create-funktiolla, hahmoa ohjataan
-- controlsin liikekutsulla ja interact-näppäintä painetaan scenen omalla näppäinkäsittelijällä.
-- Testit yrittävät rikkoa haun: kohde takana, sivulla, kaukana, iso, näkymätön, ohitettava,
-- kaksi kohdetta yhtä aikaa, kamera siirtänyt karttaa ja keksitty kolmas objektityyppi.
--
-- Käyttö:  lua5.1 verify_interact.lua [versiokansio] [versionumero]
--   [versiokansio] = polku versiokansioon (oletus: ../versio-15).
--   [versionumero] = vaihe (oletus: 15). Esineet ovat mukana versiosta 10 ja katsomissuunnan
--   tallennus versiosta 13 alkaen. Kohdehaku on olemassa versiosta 5 alkaen.

local projectDir = arg[1] or "../versio-15"
local version = tonumber( arg[2] ) or 15
package.path = projectDir .. "/?.lua;" .. package.path

------------------------------------------------------------------------------------
-- Display-objektien malli. Kaikki objektit ovat ilman kiertoa, joten contentBounds
-- ja localToContent saadaan siirroista ja skaalauksista. Objektin ankkuripiste on
-- sen x- ja y-kohdassa, kuten Solar2D:ssä.

local displayObject = {}
local displayMeta = {}

local function toContent( parent, x, y )
	while parent do
		x = parent.x + x * parent.xScale
		y = parent.y + y * parent.yScale
		parent = parent.parent
	end
	return x, y
end

local function boundsOf( object )
	if object.isGroup then
		local bounds
		for i = 1, object.numChildren do
			local childBounds = boundsOf( object[i] )
			if not bounds then
				bounds = childBounds
			else
				bounds = {
					xMin = math.min( bounds.xMin, childBounds.xMin ),
					yMin = math.min( bounds.yMin, childBounds.yMin ),
					xMax = math.max( bounds.xMax, childBounds.xMax ),
					yMax = math.max( bounds.yMax, childBounds.yMax ),
				}
			end
		end
		return bounds or { xMin = 0, yMin = 0, xMax = 0, yMax = 0 }
	end

	local width = object.width * object.xScale
	local height = object.height * object.yScale
	local left = object.x - object.anchorX * width
	local top = object.y - object.anchorY * height
	local x1, y1 = toContent( object.parent, left, top )
	local x2, y2 = toContent( object.parent, left + width, top + height )
	return { xMin = math.min( x1, x2 ), yMin = math.min( y1, y2 ), xMax = math.max( x1, x2 ), yMax = math.max( y1, y2 ) }
end

displayMeta.__index = function( object, key )
	if key == "contentBounds" then
		return boundsOf( object )
	end
	return displayObject[key]
end

local function newObject( parent, width, height, isGroup )
	local object = setmetatable( {
		x = 0,
		y = 0,
		width = width or 0,
		height = height or 0,
		anchorX = 0.5,
		anchorY = 0.5,
		xScale = 1,
		yScale = 1,
		isVisible = true,
		isGroup = isGroup,
		numChildren = 0,
		listeners = {},
	}, displayMeta )
	if parent then
		parent:insert( object )
	end
	return object
end

function displayObject:insert( child )
	if child.parent then
		child.parent:detach( child )
	end
	self.numChildren = self.numChildren + 1
	self[self.numChildren] = child
	child.parent = self
end

function displayObject:detach( child )
	for i = 1, self.numChildren do
		if self[i] == child then
			table.remove( self, i )
			self.numChildren = self.numChildren - 1
			child.parent = nil
			return
		end
	end
end

function displayObject:localToContent( x, y )
	return toContent( self, x, y )
end

function displayObject:addEventListener( name, listener )
	self.listeners[name] = listener or self
end

function displayObject:removeEventListener( name )
	self.listeners[name] = nil
end

function displayObject:setLinearVelocity( velocityX, velocityY )
	self.velocityX, self.velocityY = velocityX, velocityY
end

function displayObject:setFillColor() end

display = {
	actualContentWidth = 960,
	actualContentHeight = 640,
	newGroup = function()
		return newObject( nil, 0, 0, true )
	end,
	newImageRect = function( parent, _, _, width, height )
		return newObject( parent, width, height )
	end,
	newRect = function( parent, x, y, width, height )
		local rect = newObject( parent, width, height )
		rect.x, rect.y = x, y
		return rect
	end,
	remove = function( object )
		if not object then
			return
		end
		local finalizeListener = object.listeners.finalize
		if type( finalizeListener ) == "table" then
			finalizeListener:finalize()
		end
		if object.parent then
			object.parent:detach( object )
		end
	end,
}

graphics = {
	newImageSheet = function()
		return {}
	end,
}

-- Fysiikan stubi kirjaa rungon säteen, jotta testit laskevat kosketusetäisyydet
-- extensionien omista arvoista eivätkä toista niitä.
physics = {
	start = function() end,
	setGravity = function() end,
	addBody = function( object, _, params )
		object.bodyRadius = params and params.radius
	end,
}
package.loaded["physics"] = physics

-- enterFrame-kuuntelijat ajetaan käsin runFrame-funktiolla. buildMap tyhjentää listan.
local frameListeners = {}

Runtime = {
	addEventListener = function( _, name, listener )
		if name == "enterFrame" then
			frameListeners[#frameListeners+1] = listener
		end
	end,
	removeEventListener = function() end,
}

local function runFrame()
	for i = 1, #frameListeners do
		frameListeners[i]()
	end
end

-- Viimeisin transitio talteen, jotta testi voi asettaa objektin transition puoliväliin.
local lastTransition

transition = {
	to = function( target, params )
		lastTransition = { target = target, params = params }
	end,
	cancel = function() end,
}

easing = {}

system = {
	ResourceDirectory = "resource",
	pathForFile = function( fileName )
		return fileName
	end,
}

------------------------------------------------------------------------------------
-- Moduulistubit. Ne kirjaavat, mihin kohteeseen interact-näppäin johti.

local interactions = {}
local savedGame
local onMovementEvent
local onKeyEvent

local function record( targetName )
	interactions[#interactions+1] = targetName
end

local function noop() end

package.loaded["composer"] = {
	newScene = function()
		local scene = { view = display.newGroup() }
		function scene:addEventListener() end
		return scene
	end,
	gotoScene = noop,
}

package.loaded["json"] = {
	decodeFile = function()
		return { width = 40, height = 30, tilewidth = 32, tileheight = 32 }
	end,
}

package.loaded["scripts.controls"] = {
	start = function( movementListener, keyListener )
		onMovementEvent = movementListener
		onKeyEvent = keyListener
	end,
	stop = noop,
}

package.loaded["scripts.hints"] = { create = noop }

package.loaded["classes.camera"] = {
	init = noop,
	setBounds = noop,
	setTarget = noop,
	snapToTarget = noop,
	start = noop,
	stop = noop,
}

-- Testien NPC-hahmoilla on aina node, joka on sama kuin nimi. Versiot 5-7 tulostavat
-- nimen ja myöhemmät avaavat noden mukaisen keskustelun, joten kumpikin kertoo kohteen.
package.loaded["scripts.dialogue"] = {
	isOpen = function()
		return false
	end,
	handleKey = noop,
	open = function( node )
		record( node )
	end,
	close = noop,
	load = noop,
	save = noop,
	showMonologue = noop,
	getFlag = noop,
}

package.loaded["scripts.inventory"] = {
	slots = {},
	add = function( itemId )
		record( itemId )
		return true
	end,
	remove = noop,
	isCollected = function()
		return false
	end,
	markCollected = noop,
	restore = noop,
	setMap = noop,
	reset = noop,
	getCollected = function()
		return {}
	end,
}

package.loaded["scripts.inventoryPanel"] = {
	isOpen = function()
		return false
	end,
	open = noop,
	close = noop,
	handleKey = noop,
}

package.loaded["maps.extensions.exit"] = {}

package.loaded["maps.extensions.zone"] = {
	restore = noop,
	reset = noop,
	setMap = noop,
	getTriggered = function()
		return {}
	end,
}

package.loaded["scripts.screen"] = { centerX = 480, centerY = 320, width = 960, height = 640 }

package.loaded["scripts.loadsave"] = {
	save = function( state )
		savedGame = state
	end,
	load = function()
		return savedGame
	end,
	delete = noop,
}

package.loaded["scripts.sfx"] = { playInteract = noop }
package.loaded["scripts.music"] = { playForMap = noop, stop = noop }

------------------------------------------------------------------------------------
-- Kartan stubi. ponytiled.new rakentaa kartan nykyisen testin objekteista: jokainen
-- objekti on Tiled-placeholder, jolle ponytiled on kopioinut Tiledin ominaisuudet.
-- extend ja listTypes toimivat kuten ponytiledissä.

local scenarioObjects = {}

-- Kamera siirtää koko karttaryhmää, joten kartta on jokaisessa testissä siirretty pois origosta.
local mapOffsetX, mapOffsetY = -173, -91

package.loaded["com.ponywolf.ponytiled"] = {
	new = function()
		local map = newObject( nil, 0, 0, true )
		map.x, map.y = mapOffsetX, mapOffsetY

		local gameLayer = newObject( map, 0, 0, true )
		gameLayer.name = "game"
		local physicsLayer = newObject( map, 0, 0, true )
		physicsLayer.name = "physics"

		for i = 1, #scenarioObjects do
			local placeholder = newObject( gameLayer, 32, 32 )
			for key, value in pairs( scenarioObjects[i] ) do
				placeholder[key] = value
			end
		end

		function map:findLayer( name )
			for i = 1, self.numChildren do
				if self[i].name == name then
					return self[i]
				end
			end
		end

		function map:listTypes( ... )
			local types = { ... }
			local objects = {}
			for layerIndex = self.numChildren, 1, -1 do
				local layer = self[layerIndex]
				for i = layer.numChildren, 1, -1 do
					for typeIndex = 1, #types do
						if layer[i].type == types[typeIndex] then
							objects[#objects+1] = layer[i]
						end
					end
				end
			end
			return objects
		end

		function map:extend( ... )
			local names = { ... }
			for nameIndex = 1, #names do
				local plugin = require( self.extensions .. names[nameIndex] )
				local placeholders = self:listTypes( names[nameIndex] )
				for i = 1, #placeholders do
					plugin.new( placeholders[i] )
				end
			end
		end

		function map:findObject( name )
			for layerIndex = 1, self.numChildren do
				local layer = self[layerIndex]
				for i = 1, layer.numChildren do
					if layer[i].name == name then
						return layer[i]
					end
				end
			end
		end

		function map:sortLayer() end

		return map
	end,
}

------------------------------------------------------------------------------------
-- Assertit ja testiapurit

local failures = 0

local function check( condition, message )
	if condition then
		print( "  PASS  " .. message )
	else
		failures = failures + 1
		print( "  FAIL  " .. message )
	end
end

local scene = dofile( projectDir .. "/scenes/game.lua" )

local map
local hero

-- Rakentaa kartan annetuista objekteista. Pelaajahahmo on kartan kohdassa (0, 0).
local function buildMap( objects, params )
	frameListeners = {}
	scenarioObjects = { { type = "hero", name = "hero" } }
	for i = 1, #objects do
		scenarioObjects[#scenarioObjects+1] = objects[i]
	end

	scene:create( { params = params or { mapName = "village" } } )
	scene:show( { phase = "did" } )

	map = scene.view[scene.view.numChildren]
	hero = map:findObject( "hero" )
	return map
end

local function npcAt( name, x, y, extra )
	local object = { type = "npc", name = name, node = name, x = x, y = y }
	for key, value in pairs( extra or {} ) do
		object[key] = value
	end
	return object
end

local function itemAt( name, x, y, extra )
	local object = { type = "item", name = name, item = name, x = x, y = y }
	for key, value in pairs( extra or {} ) do
		object[key] = value
	end
	return object
end

-- Kääntää hahmon liikkumalla suuntaan ja pysähtymällä, kuten controls tekee.
local function face( directionX, directionY )
	onMovementEvent( directionX, directionY )
	onMovementEvent( 0, 0 )
end

-- Painaa interact-näppäintä ja palauttaa kohteen nimen tai false.
local function pressInteract()
	interactions = {}
	local printed = {}
	local originalPrint = print
	-- game.lua kertoo kohteen tai sen puuttumisen globaalilla print-funktiolla, joten se korvataan painalluksen ajaksi.
	_G.print = function( text )
		printed[#printed+1] = tostring( text )
	end
	onKeyEvent( "interact", "down" )
	_G.print = originalPrint

	for i = 1, #printed do
		local talkedTo = printed[i]:match( "^Talking to: (.*)$" )
		if talkedTo then
			record( talkedTo )
		end
	end

	if #interactions > 1 then
		return "useita: " .. table.concat( interactions, ", " )
	end
	return interactions[1] or false
end

-- Hakee scenen paikallisen findInteractTarget-funktion näppäinkäsittelijän upvaluesta,
-- jotta haulle voi antaa myös objektityyppejä, joita peli ei itse anna.
local function getFindInteractTarget()
	local index = 1
	while true do
		local name, value = debug.getupvalue( onKeyEvent, index )
		if not name then
			return nil
		end
		if name == "findInteractTarget" then
			return value
		end
		index = index + 1
	end
end

local diagonal = math.sqrt( 0.5 )
local directions = {
	{ name = "oikealle", x = 1, y = 0 },
	{ name = "vasemmalle", x = -1, y = 0 },
	{ name = "alas", x = 0, y = 1 },
	{ name = "ylös", x = 0, y = -1 },
	{ name = "viistosti oikealle alas", x = diagonal, y = diagonal },
	{ name = "viistosti vasemmalle ylös", x = -diagonal, y = -diagonal },
}

print( "== interact-testi (" .. projectDir .. ", versio " .. version .. ") ==" )

-- Rungon säteet luetaan oikeista extensioneista.
buildMap( { npcAt( "probe", 500, 500 ), version >= 10 and itemAt( "probeItem", 600, 600 ) or nil } )
local heroRadius = hero.bodyRadius
local npcRadius = map:findObject( "probe" ).bodyRadius
local itemRadius = version >= 10 and map:findObject( "probeItem" ).bodyRadius
local npcTouching = heroRadius + npcRadius

------------------------------------------------------------------------------------
-- 1. Aloitussuunta ja suunnan säilyminen

check( hero.facingX == 0 and hero.facingY == 1, "hahmo katsoo aluksi alas (0, 1)" )

buildMap( { npcAt( "below", 0, npcTouching ), npcAt( "above", 0, -npcTouching ) } )
check( pressInteract() == "below", "liikkumaton hahmo löytää alla koskettavan NPC:n, ei yllä olevaa" )

buildMap( { npcAt( "left", -npcTouching, 0 ), npcAt( "right", npcTouching, 0 ) } )
face( -1, 0 )
check( hero.facingX == -1 and hero.facingY == 0, "suunta säilyy, kun hahmo pysähtyy (0, 0)" )
hero:stop()
check( hero.facingX == -1 and hero.facingY == 0, "suunta säilyy hero:stop()-kutsun jälkeen" )
check( pressInteract() == "left", "pysähtynyt hahmo löytää kohteen viimeisestä liikesuunnasta" )

-- Sprite kääntyy vain vasemmalle ja oikealle, ja pystysuora liike pitää edellisen käännön.
buildMap( {} )
local moves = { { -1, 0 }, { 0, -1 }, { 0, 0 }, { 1, 0 }, { 0, 1 }, { 0, 0 } }
local flips = {}
for i = 1, #moves do
	onMovementEvent( moves[i][1], moves[i][2] )
	runFrame()
	flips[i] = hero.sprite.xScale
end
check( flips[1] == -1 and flips[2] == -1 and flips[3] == -1, "sprite kääntyy vasemmalle ja pysyy niin, kun hahmo liikkuu ylös ja pysähtyy" )
check( flips[4] == 1 and flips[5] == 1 and flips[6] == 1, "sprite kääntyy oikealle ja pysyy niin, kun hahmo liikkuu alas ja pysähtyy" )

------------------------------------------------------------------------------------
-- 2. Koskettava kohde jokaisessa suunnassa, ei takana eikä sivulla

for i = 1, #directions do
	local direction = directions[i]
	local frontX, frontY = direction.x * npcTouching, direction.y * npcTouching
	buildMap( { npcAt( "front", frontX, frontY ) } )
	face( direction.x, direction.y )
	check( pressInteract() == "front", "koskettava NPC löytyy, kun hahmo katsoo " .. direction.name )

	buildMap( { npcAt( "behind", -frontX, -frontY ) } )
	face( direction.x, direction.y )
	check( pressInteract() == false, "koskettava NPC takana ei löydy, kun hahmo katsoo " .. direction.name )

	buildMap( { npcAt( "side", -direction.y * npcTouching, direction.x * npcTouching ) } )
	face( direction.x, direction.y )
	check( pressInteract() == false, "koskettava NPC sivulla ei löydy, kun hahmo katsoo " .. direction.name )

	buildMap( { npcAt( "gap", direction.x * ( npcTouching + 10 ), direction.y * ( npcTouching + 10 ) ) } )
	face( direction.x, direction.y )
	check( pressInteract() == "gap", "NPC löytyy 10 pikselin raolla, kun hahmo katsoo " .. direction.name )
end

buildMap( { npcAt( "front", npcTouching + 10, 0 ), npcAt( "behind", -npcTouching, 0 ) } )
face( 1, 0 )
check( pressInteract() == "front", "edessä oleva kohde voittaa takana olevan, vaikka takana oleva on lähempänä" )

buildMap( { npcAt( "far", npcTouching + 40, 0 ) } )
face( 1, 0 )
check( pressInteract() == false, "kaukana edessä oleva NPC ei löydy, ja haku palauttaa nil" )

buildMap( {} )
check( pressInteract() == false, "tyhjä kartta: kohdetta ei löydy" )

------------------------------------------------------------------------------------
-- 3. Iso objekti, ankkuri, näkyvyys ja ignoreInteract

-- 200x200-kokoinen NPC, jonka yläreunaa hahmo koskettaa alhaalta päin eri kohdista.
local bigSize = 200
local bigFound = true
for offset = -bigSize * 0.5, bigSize * 0.5, 20 do
	buildMap( { npcAt( "big", offset, -( bigSize * 0.5 + heroRadius ) ) } )
	local big = map:findObject( "big" )
	big.width, big.height = bigSize, bigSize
	face( 0, -1 )
	if pressInteract() ~= "big" then
		bigFound = false
		print( "        iso objekti ei löytynyt kohdasta " .. offset )
	end
end
check( bigFound, "200x200-objekti löytyy, kun hahmo koskettaa sen reunaa missä kohdassa tahansa" )

-- Tiledin tapaan vasempaan alakulmaan ankkuroitu objekti, jonka vasen reuna koskettaa hahmoa.
buildMap( { npcAt( "anchored", 0, 0 ) } )
local anchored = map:findObject( "anchored" )
anchored.anchorX, anchored.anchorY = 0, 1
anchored.x, anchored.y = heroRadius, 16
face( 1, 0 )
check( pressInteract() == "anchored", "ankkuriltaan (0, 1) oleva objekti löytyy reunansa perusteella" )
face( -1, 0 )
check( pressInteract() == false, "ankkuriltaan (0, 1) oleva objekti ei löydy, kun hahmo katsoo poispäin" )

buildMap( { npcAt( "hidden", npcTouching, 0 ) } )
map:findObject( "hidden" ).isVisible = false
face( 1, 0 )
check( pressInteract() == "hidden", "näkymätön objekti kelpaa kohteeksi" )

buildMap( { npcAt( "ignoredTiled", npcTouching, 0, { ignoreInteract = true } ) } )
face( 1, 0 )
check( pressInteract() == false, "Tiledin ignoreInteract-ominaisuus ohittaa NPC:n" )
check( map:findObject( "ignoredTiled" ).ignoreInteract == true, "npc-extension säilyttää Tiledin ignoreInteract-ominaisuuden" )

buildMap( { npcAt( "ignoredCode", npcTouching, 0 ), npcAt( "kept", npcTouching + 4, 0 ) } )
map:findObject( "ignoredCode" ).ignoreInteract = true
face( 1, 0 )
check( pressInteract() == "kept", "koodissa asetettu ignoreInteract ohittaa NPC:n, ja haku valitsee seuraavan" )

buildMap( { npcAt( "notIgnored", npcTouching, 0, { ignoreInteract = false } ) } )
face( 1, 0 )
check( pressInteract() == "notIgnored", "Tiledin ignoreInteract = false ei ohita NPC:tä" )

-- Pomppaava NPC (versio 15) on pompun aikana perusasentoaan ylempänä. Hahmo koskettaa
-- sitä perusasennossa, ja NPC asetetaan pompun transition puoliväliin ja huippuun.
buildMap( { npcAt( "probeBounce", 500, 500 ) } )
if map:findObject( "probeBounce" ).bounce then
	local bounceDirections = {
		{ name = "oikealle", x = 1, y = 0 },
		{ name = "ylös", x = 0, y = -1 },
		{ name = "alas", x = 0, y = 1 },
	}
	local fractions = { 0.5, 1 }
	for i = 1, #bounceDirections do
		local direction = bounceDirections[i]
		buildMap( { npcAt( "bouncing", direction.x * npcTouching, direction.y * npcTouching ) } )
		local bouncing = map:findObject( "bouncing" )
		face( direction.x, direction.y )
		bouncing:bounce()
		local topY = lastTransition.params.y
		for fractionIndex = 1, #fractions do
			local lift = ( bouncing.baseY - topY ) * fractions[fractionIndex]
			bouncing.y = bouncing.baseY - lift
			check( pressInteract() == "bouncing", "pompun aikana " .. lift .. " pikseliä ylempänä oleva NPC löytyy, kun hahmo katsoo " .. direction.name )
		end
	end
end

------------------------------------------------------------------------------------
-- 4. Kaksi kohdetta ulottuvilla: lähempi reuna voittaa

-- Paikat lasketaan pelin omista säätöarvoista: hahmo katsoo oikealle, joten vuorovaikutuspiste
-- on kohdassa (interactReach, 0), ja kummankin kohteen reuna on pisteen ulkopuolella.
local gameConfig = require( "data.gameConfig" )
local pointX = gameConfig.interactReach
local radius = gameConfig.interactRadius
local halfSize = 16

for order = 1, 2 do
	local nearer = npcAt( "nearer", pointX + radius * 0.25 + halfSize, 0 )
	local farther = npcAt( "farther", pointX + radius * 0.75 + halfSize, 0 )
	buildMap( order == 1 and { nearer, farther } or { farther, nearer } )
	face( 1, 0 )
	check( pressInteract() == "nearer", "lähempi reuna voittaa (järjestys " .. order .. ")" )
end

-- Leveän objektin reuna on lähempänä, vaikka sen keskipiste on kauempana kuin kapean.
for order = 1, 2 do
	local wide = npcAt( "wide", pointX + radius * 0.25 + halfSize * 2, 0 )
	local narrow = npcAt( "narrow", pointX, -( radius * 0.75 + halfSize ) )
	buildMap( order == 1 and { wide, narrow } or { narrow, wide } )
	local wideObject = map:findObject( "wide" )
	wideObject.width = 64
	face( 1, 0 )
	check( pressInteract() == "wide", "lähempi reuna voittaa lähemmän keskipisteen (järjestys " .. order .. ")" )
end

------------------------------------------------------------------------------------
-- 5. Esineet NPC-hahmojen rinnalla (versiosta 10)

if version >= 10 then
	local itemTouching = heroRadius + itemRadius

	buildMap( { itemAt( "frontItem", itemTouching, 0 ), npcAt( "behindNpc", -npcTouching, 0 ) } )
	face( 1, 0 )
	check( pressInteract() == "frontItem", "edessä oleva esine valitaan takana olevan NPC:n sijaan" )

	buildMap( { npcAt( "frontNpc", 0, -npcTouching ), itemAt( "sideItem", itemTouching, 0 ) } )
	face( 0, -1 )
	check( pressInteract() == "frontNpc", "edessä oleva NPC valitaan sivulla olevan esineen sijaan" )

	buildMap( { itemAt( "sideItem", 0, itemTouching ), itemAt( "sideItem2", 0, -itemTouching ) } )
	face( 1, 0 )
	check( pressInteract() == false, "sivulla koskettava esine ei löydy" )

	buildMap( { itemAt( "gapItem", itemTouching + 10, 0 ) } )
	face( 1, 0 )
	check( pressInteract() == "gapItem", "esine löytyy 10 pikselin raolla" )

	buildMap( { itemAt( "ignoredItem", itemTouching, 0, { ignoreInteract = true } ) } )
	face( 1, 0 )
	check( pressInteract() == false, "Tiledin ignoreInteract-ominaisuus ohittaa esineen" )
end

------------------------------------------------------------------------------------
-- 6. Keksitty kolmas objektityyppi: haku ei riipu NPC:n tai esineen kentistä

buildMap( { npcAt( "npcBehind", -npcTouching, 0 ) } )
face( 1, 0 )
local findInteractTarget = getFindInteractTarget()
check( findInteractTarget ~= nil, "näppäinkäsittelijä käyttää findInteractTarget-funktiota" )

if findInteractTarget then
	local sign = newObject( map:findLayer( "game" ), 48, 24 )
	sign.type = "sign"
	sign.x, sign.y = heroRadius + 24, 0
	check( findInteractTarget( hero, map:listTypes( "sign" ) ) == sign, "keksitty sign-tyyppi löytyy, kun se annetaan haulle" )
	check( findInteractTarget( hero, map:listTypes( "npc", "item", "sign" ) ) == sign, "sign löytyy NPC:n ja esineen rinnalla" )
	check( findInteractTarget( hero, map:listTypes( "npc" ) ) == nil, "haku palauttaa nil, kun ulottuvilla ei ole kohdetta" )
	check( findInteractTarget( hero, {} ) == nil, "haku palauttaa nil tyhjälle listalle" )

	-- Mitattu raja: suurin rako hahmon ja edessä olevan kohteen fysiikkarunkojen välillä.
	local function largestGap( bodyRadius )
		local largest = -1
		for gap = 0, 40, 0.5 do
			local candidate = newObject( map:findLayer( "game" ), 32, 32 )
			candidate.x, candidate.y = heroRadius + bodyRadius + gap, 0
			if findInteractTarget( hero, { candidate } ) then
				largest = gap
			end
			display.remove( candidate )
		end
		return largest
	end

	-- Sivulla koskettava kohde liu'utetaan hahmon kohdalta 40 pikseliä eteenpäin.
	local function sidewaysTouchingFound( bodyRadius )
		for forward = 0, 40, 0.5 do
			local candidate = newObject( map:findLayer( "game" ), 32, 32 )
			candidate.x, candidate.y = forward, heroRadius + bodyRadius
			local found = findInteractTarget( hero, { candidate } )
			display.remove( candidate )
			if found then
				return true
			end
		end
		return false
	end

	-- Suurin sivuttaissiirto, jolla vuorovaikutuspisteen kohdalla oleva 32x32-kohde vielä löytyy.
	local function largestSideOffset()
		local largest = -1
		for offset = 0, 40, 0.5 do
			local candidate = newObject( map:findLayer( "game" ), 32, 32 )
			candidate.x, candidate.y = gameConfig.interactReach, offset
			if findInteractTarget( hero, { candidate } ) then
				largest = offset
			end
			display.remove( candidate )
		end
		return largest
	end

	check( not sidewaysTouchingFound( npcRadius ), "sivulla koskettava NPC ei löydy, vaikka se olisi 0-40 pikseliä edempänä" )
	if itemRadius then
		check( not sidewaysTouchingFound( itemRadius ), "sivulla koskettava esine ei löydy, vaikka se olisi 0-40 pikseliä edempänä" )
	end

	print( "        mitattu: suurin rako edessä NPC " .. largestGap( npcRadius ) .. ( itemRadius and ( ", esine " .. largestGap( itemRadius ) ) or "" )
		.. "; suurin keskipisteen sivuttaissiirto " .. largestSideOffset() )
end

------------------------------------------------------------------------------------
-- 7. Katsomissuunnan tallennus ja lataus (versiosta 13)

if version >= 13 then
	buildMap( {} )
	face( -1, 0 )
	onKeyEvent( "menu", "down" )
	check( savedGame and savedGame.facingX == -1 and savedGame.facingY == 0, "tallennus sisältää katsomissuunnan" )

	buildMap( { npcAt( "loaded", -npcTouching, 0 ) }, { load = true } )
	check( hero.facingX == -1 and hero.facingY == 0, "lataus palauttaa katsomissuunnan" )
	check( pressInteract() == "loaded", "ladattu katsomissuunta ohjaa haun" )

	savedGame = { mapName = "village", playerX = 0, playerY = 0, inventory = {}, collected = {} }
	buildMap( { npcAt( "below", 0, npcTouching ) }, { load = true } )
	check( hero.facingX == 0 and hero.facingY == 1, "vanha tallennus ilman suuntaa: hahmo katsoo alas" )
	check( pressInteract() == "below", "vanha tallennus ilman suuntaa ei kaada hakua" )
end

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI" )
	os.exit( 1 )
end
