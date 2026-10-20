-- Game-scene. Tällä oppitunnilla lataamme ja näytämme pelin ensimmäisen kentän.

-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- json lukee Tiled-editorista viedyn kenttätiedoston Lua-taulukoksi.
local json = require( "json" )
-- ponytiled rakentaa Tiled-kartasta valmiin display-objektin.
local ponytiled = require( "com.ponywolf.ponytiled" )
-- physics tarvitaan hahmon ja seinien fysiikkaobjekteihin.
local physics = require( "physics" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()

-- Kartta, jonka lataamme tähän sceneen.
local map

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
	-- Lisäämme ensimmäisen extensionin, pelaajahahmon, seuraavalla oppitunnilla.
	map.extensions = "maps.extensions."

	-- Lisätään kartta scenen ryhmään, jotta se piirtyy ruudulle.
	sceneGroup:insert( map )
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.


	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene on piilotettu.


	end
end


-- destroy: kutsutaan kun scene halutaan poistaa kokonaan.
-- Täällä siivotaan kaikki objektit ja resurssit.
function scene:destroy( event )
	-- Poistetaan kartta ja nollataan viittaus, jotta muistista ei jää roskaa.
	display.remove( map )
	map = nil
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
