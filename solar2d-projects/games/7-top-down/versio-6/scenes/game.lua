-- Game-scene. Tällä oppitunnilla lisäämme kameran seuraamaan pelaajaa.

-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- json lukee Tiled-editorista viedyn kenttätiedoston Lua-taulukoksi.
local json = require( "json" )
-- ponytiled rakentaa Tiled-kartasta valmiin display-objektin.
local ponytiled = require( "com.ponywolf.ponytiled" )
-- physics tarvitaan hahmon ja seinien fysiikkaobjekteihin.
local physics = require( "physics" )
-- controls kuuntelee näppäimistöä ja antaa liikkeen suunnan.
local controls = require( "scripts.controls" )
-- camera seuraa pelaajaa ja vierittää karttaa isoilla kentillä.
local camera = require( "classes.camera" )

-- hints näyttää pelin ohjausvinkit ruudun alakulmassa.
local hints = require( "scripts.hints" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()

-- Kartta ja pelaajahahmo, joita käytämme useassa scene-funktiossa.
local map
local player

--------------------------------------------------------------------------------------
-- Muut funktiot:
--------------------------------------------------------------------------------------

-- controls kutsuu tätä joka framella ja antaa normalisoidun liikevektorin.
-- Välitetään vektori pelaajahahmolle, joka hoitaa varsinaisen liikkeen.
local function onMovementEvent( directionX, directionY )
	if player and player.move then
		player:move( directionX, directionY )
	end
end


-- controls kutsuu tätä, kun pelaaja painaa tai vapauttaa toimintonäppäimen.
-- Ammutaan lyhyt säde hahmon katsomissuuntaan ja katsotaan, osuuko se NPC-hahmoon.
local function onKeyEvent( action, phase )
	if action == "interact" and phase == "down" then
		if player and player.getFacing then
			local facingX, facingY = player:getFacing()

			-- Säde alkaa hahmon keskeltä. rayCast ei ilmoita objektia, jonka sisältä
			-- säde lähtee, joten hahmo ei osu itseensä.
			local reach = 34
			local toX = player.x + facingX * reach
			local toY = player.y + facingY * reach

			local hits = physics.rayCast( player.x, player.y, toX, toY, "closest" )
			if hits and hits[1] and hits[1].object.type == "npc" then
				print( "Talking to: " .. tostring( hits[1].object.name ) )
			else
				print( "There is nobody ahead to talk to." )
			end
		end
	end
end

--------------------------------------------------------------------------------------
-- scene event -funktiot:
--------------------------------------------------------------------------------------

-- create: kutsutaan kun scene luodaan ensimmäistä kertaa,
-- tai jos se on poistettu ja sitä luodaan uudelleen.
function scene:create( event )
	local sceneGroup = self.view

	-- Käynnistetään fysiikka ennen kartan rakentamista, sillä kartan physics-layer
	-- luo seinien fysiikkaobjektit heti kun kartta rakennetaan. Top-down-pelissä
	-- ei ole painovoimaa, joten asetamme sen nollaan molemmilla akseleilla.
	physics.start()
	physics.setGravity( 0, 0 )

	-- Luetaan kyläkartta JSON-tiedostosta Lua-taulukoksi.
	local mapData = json.decodeFile( system.pathForFile( "maps/village.json", system.ResourceDirectory ) )

	-- Rakennetaan kartasta display-objekti. Toinen argumentti kertoo, mistä
	-- kansiosta kartan kuvatiedostot löytyvät.
	map = ponytiled.new( mapData, "maps" )

	-- Piilotetaan physics-layer, jolla ovat näkymättömät seinät ja siirtymät.
	-- Kartassa layer on jo merkitty piilotetuksi, mutta piilotamme sen myös
	-- koodissa, jotta näet miten yksittäisen layerin saa haettua ja kätkettyä.
	local physicsLayer = map:findLayer( "physics" )
	if physicsLayer then
		physicsLayer.isVisible = false
	end

	-- ponytilediä voidaan laajentaa lisäosilla (extensions); kerrotaan, mistä kansiosta ne löytyvät.
	map.extensions = "maps.extensions."

	-- Ajetaan extensionit: hero korvaa "hero"-objektin pelaajalla ja npc rakentaa
	-- jokaisesta "npc"-objektista oman hahmonsa.
	map:extend( "hero", "npc" )

	-- Haetaan valmis pelaajahahmo talteen. Jos kartalta puuttuu hero-objekti,
	-- kerromme siitä heti, jotta virhe huomataan kehityksen aikana.
	player = map:findObject( "hero" )
	if not player then
		print( "WARNING: the map is missing the hero object." )
	end

	-- Kytketään kamera seuraamaan pelaajaa. Kamera liikuttaa koko karttaryhmää,
	-- joten annamme sille kartan yhtenä layerina (delta 1 = liikkuu kameran mukana).
	camera.init( { { group = map, delta = 1 } } )

	-- Lasketaan kameran rajat kartan pikselikoosta, jotta kamera ei näytä kartan
	-- reunojen ylitse. Rajat kertovat, kuinka lähelle reunaa kameran keskipiste voi mennä.
	local mapPixelWidth = mapData.width * mapData.tilewidth
	local mapPixelHeight = mapData.height * mapData.tileheight
	local halfScreenWidth = display.actualContentWidth * 0.5
	local halfScreenHeight = display.actualContentHeight * 0.5

	local boundsXMin = halfScreenWidth
	local boundsXMax = mapPixelWidth - halfScreenWidth
	local boundsYMin = halfScreenHeight
	local boundsYMax = mapPixelHeight - halfScreenHeight

	-- Jos kartta on ruutua pienempi jollain akselilla, keskitämme kartan sille
	-- akselille (esim. talon sisätila, joka mahtuu kerralla ruudulle).
	if boundsXMin > boundsXMax then
		boundsXMin = mapPixelWidth * 0.5
		boundsXMax = boundsXMin
	end
	if boundsYMin > boundsYMax then
		boundsYMin = mapPixelHeight * 0.5
		boundsYMax = boundsYMin
	end

	camera.setBounds( { xMin = boundsXMin, yMin = boundsYMin, xMax = boundsXMax, yMax = boundsYMax } )

	-- Asetetaan pelaaja kameran seurattavaksi ja siirretään kamera heti kohdalleen,
	-- jottei kuva nytkähdä pelin alkaessa.
	if player then
		camera.setTarget( player, { smoothing = 0.3 } )
		camera.snapToTarget()
	end

	-- Lisätään kartta scenen ryhmään, jotta se piirtyy ruudulle.
	sceneGroup:insert( map )

	-- Luodaan ohjausvinkit ruudun alakulmaan. Ne ovat scene-ryhmässä, joten ne
	-- pysyvät paikallaan eivätkä liiku kameran mukana.
	hints.create( sceneGroup )
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.

		-- Aletaan kuunnella liikkumisnäppäimiä ja toimintonäppäintä.
		controls.start( onMovementEvent, onKeyEvent )

		-- Käynnistetään kameran seuranta.
		camera.start()

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		-- Lopetetaan näppäinten kuuntelu, kameran seuranta ja pysäytetään hahmo.
		controls.stop()
		camera.stop()
		if player and player.stop then
			player:stop()
		end

	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene on piilotettu.


	end
end


-- destroy: kutsutaan kun scene halutaan poistaa kokonaan.
-- Täällä siivotaan kaikki objektit ja resurssit.
function scene:destroy( event )
	-- Poistetaan kartta ja nollataan viittaukset, jotta muistista ei jää roskaa.
	-- Pelaajahahmo on kartan sisällä, joten se poistuu kartan mukana.
	display.remove( map )
	map = nil
	player = nil
end


--------------------------------------------------------------------------------------
-- Scene event -listenerit:
-- Voit valita mitä eventtejä haluat kuunnella. Jos et esimerkiksi koskaan
-- poista sceneä, niin silloin "destroy" ei välttämättä ole tarpeellinen.
--------------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
--------------------------------------------------------------------------------------

-- Lopuksi palautetaan scene, jolloin tiedosto toimii Lua-moduulina.
return scene
