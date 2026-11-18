-- Game-scene. Tällä oppitunnilla lisäämme vuorovaikutuksen ja NPC-hahmot.

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

-- hints näyttää pelin ohjausvinkit ruudun alakulmassa.
local hints = require( "scripts.hints" )

-- gameConfig sisältää pelin säätöarvot, kuten vuorovaikutuksen ulottuvuuden.
local gameConfig = require( "data.gameConfig" )

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


-- Etsii pelaajahahmon edestä kohteen, jonka kanssa hahmo voi olla vuorovaikutuksessa.
-- candidates on lista kohteiksi kelpaavista objekteista. Palauttaa lähimmän kohteen tai nil.
local function findInteractTarget( hero, candidates )
	-- Objektien contentBounds-reunat ovat ruudun koordinaatteja, joten hahmon keskipiste muunnetaan
	-- layerin koordinaateista samoihin koordinaatteihin.
	local heroX, heroY = hero.parent:localToContent( hero.x, hero.y )

	-- Vuorovaikutuspiste on hahmon edessä katsomissuuntaan, joten kohde löytyy vain hahmon edestä.
	local pointX = heroX + hero.facingX * gameConfig.interactReach
	local pointY = heroY + hero.facingY * gameConfig.interactReach

	local target

	-- math.huge on suurempi kuin mikään etäisyys, joten ensimmäinen ulottuvilla oleva objekti on aina lähempänä.
	local targetDistance = math.huge

	for i = 1, #candidates do
		local candidate = candidates[i]

		-- Objekti, jonka ignoreInteract on tosi, ei ole koskaan kohde. Arvon voi antaa Tiledissä tai koodissa.
		if not candidate.ignoreInteract then
			-- Etäisyys mitataan objektin lähimpään reunaan eikä keskipisteeseen, jotta myös iso
			-- objekti löytyy, kun hahmo on sen vieressä. contentBounds kertoo objektin reunat sen
			-- koosta ja ankkurista riippumatta. Kun piste rajataan reunojen väliin, saadaan
			-- objektin lähin piste. Jos piste on objektin sisällä, etäisyys on nolla.
			local bounds = candidate.contentBounds
			local nearestX = math.min( math.max( pointX, bounds.xMin ), bounds.xMax )
			local nearestY = math.min( math.max( pointY, bounds.yMin ), bounds.yMax )
			local distanceX = nearestX - pointX
			local distanceY = nearestY - pointY
			local distance = math.sqrt( distanceX * distanceX + distanceY * distanceY )

			-- Objekti kelpaa, kun sen reuna on enintään interactRadius-etäisyydellä pisteestä.
			-- Lähempänä oleva kohde korvaa aiemmin löydetyn.
			if distance <= gameConfig.interactRadius and distance < targetDistance then
				target = candidate
				targetDistance = distance
			end
		end
	end

	return target
end


-- controls kutsuu tätä, kun pelaaja painaa tai vapauttaa näppäimen, johon on liitetty toiminto.
-- Interact-näppäin etsii pelaajahahmon edestä kohteen, jolle pelaaja puhuu.
local function onKeyEvent( action, phase )
	if action == "interact" and phase == "down" then
		if player then
			-- listTypes antaa kartan objektit, joiden kanssa pelaajahahmo voi olla vuorovaikutuksessa.
			-- Tässä vaiheessa niitä ovat vain NPC-hahmot. Uusi kohdetyyppi lisätään tähän kutsuun,
			-- ja sille kirjoitetaan alle oma haaransa.
			local target = findInteractTarget( player, map:listTypes( "npc" ) )

			if target then
				print( "Talking to: " .. tostring( target.name ) )
			else
				print( "There is nothing nearby to interact with." )
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

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		-- Lopetetaan näppäinten kuuntelu ja pysäytetään hahmo.
		controls.stop()
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
