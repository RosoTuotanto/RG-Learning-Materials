-- Game-scene. Tällä oppitunnilla viimeistelemme pelin: taustahahmojen repliikit, palaute ja viestitriggerit.

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
-- dialogue lataa tarinan ja piirtää NPC-keskustelut ruudulle.
local dialogue = require( "scripts.dialogue" )
-- inventory säilyttää repun sisällön ja poimittujen esineiden rekisterin.
local inventory = require( "scripts.inventory" )
-- inventoryPanel piirtää repun ruudukkonäkymän ja käsittelee sen näppäimet.
local inventoryPanel = require( "scripts.inventoryPanel" )
-- exit on sama moduuli, jonka ponytiled ajaa "exit"-objekteille. Game-scene kertoo
-- sille, miten lukitun portin viesti näytetään.
local exit = require( "maps.extensions.exit" )
-- zone näyttää pelaajan kommentin, kun pelaaja astuu kartan viestitriggeriin.
-- Sama moduuli, jonka ponytiled ajaa kartan "zone"-objekteille extensionina.
local zone = require( "maps.extensions.zone" )
-- screen auttaa asettamaan käyttöliittymän ruudun reunaan.
local screen = require( "scripts.screen" )
-- loadsave lukee ja kirjoittaa pelitilan tallennustiedoston.
local loadsave = require( "scripts.loadsave" )
-- sfx soittaa ääniefektit ja music hoitaa ulko- ja sisätilan taustamusiikin.
local sfx = require( "scripts.sfx" )
local music = require( "scripts.music" )

-- hints näyttää pelin ohjausvinkit ruudun alakulmassa.
local hints = require( "scripts.hints" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()

-- Pelitilan tallennustiedosto. Sama nimi on käytössä menussa (scenes/menu.lua).
local saveFile = "gamesave.json"

-- Kartta ja pelaajahahmo, joita käytämme useassa scene-funktiossa.
local map
local player

-- Parhaillaan avoinna oleva kartta. Tarvitsemme sen tallennukseen.
local currentMapName

-- Ryhmä, johon keskustelu- ja inventory-ikkuna piirretään. Se ei liiku kameran
-- mukana, joten ne pysyvät paikallaan ruudulla.
local dialogueGroup

-- Tosi, kun peli alkaa alusta. Silloin game-scenen avauduttua näytetään
-- aloitusrepliikki, joka ohjaa pelaajan kylän vanhimman luo.
local newGame

--------------------------------------------------------------------------------------
-- Muut funktiot:
--------------------------------------------------------------------------------------

-- Weaver antaa omat <<...>>-komennot pelin käsiteltäväksi taulukkoina. Marlow antaa
-- viestin komennolla "annaViesti", ja kylän vanhin ottaa sen vastaan komennolla "toimitaViesti".
local function onDialogueCommand( command )
	if command[1] == "annaViesti" then
		inventory.add( "note" )
	elseif command[1] == "toimitaViesti" then
		inventory.remove( "note" )
	end
end


-- Tallennetaan pelitila: nykyinen kartta, pelaajan sijainti ja katsomissuunta, repun
-- sisältö sekä poimittujen esineiden ja laukeneiden triggereiden rekisterit. Tarinan tila
-- tallennetaan samalla hetkellä Weaverin omaan tiedostoon. Näin "Continue" voi palauttaa
-- kaiken samaan tilaan.
local function saveGame()
	if not player then return end

	local facingX, facingY = player:getFacing()

	loadsave.save( {
		mapName = currentMapName,
		playerX = player.x,
		playerY = player.y,
		facing = { x = facingX, y = facingY },
		inventory = inventory.slots,
		collected = inventory.getCollected(),
		zones = zone.getTriggered(),
	}, saveFile )

	dialogue.save()
end


-- controls kutsuu tätä joka framella ja antaa normalisoidun liikevektorin.
-- Välitetään vektori pelaajahahmolle, joka hoitaa varsinaisen liikkeen.
local function onMovementEvent( directionX, directionY )
	-- Keskustelun tai repun ollessa auki hahmo ei liiku, vaan pysähtyy paikoilleen.
	if dialogue.isOpen() or inventoryPanel.isOpen() then
		if player and player.stop then
			player:stop()
		end
		return
	end

	if player and player.move then
		player:move( directionX, directionY )
	end
end


-- controls kutsuu tätä, kun pelaaja painaa tai vapauttaa toimintonäppäimen.
-- Ammutaan lyhyt säde hahmon katsomissuuntaan ja katsotaan, osuuko se NPC-hahmoon.
local function onKeyEvent( action, phase )
	-- Kun keskustelu on auki, kaikki näppäimet ohjataan dialogille.
	if dialogue.isOpen() then
		dialogue.handleKey( action, phase )
		return
	end

	-- Kun reppu on auki, näppäimet ohjataan inventoryyn. Menu-näppäin sulkee repun
	-- sen sijaan että tallentaisi ja poistuisi pelistä.
	if inventoryPanel.isOpen() then
		if action == "menu" and phase == "down" then
			inventoryPanel.close()
		else
			inventoryPanel.handleKey( action, phase )
		end
		return
	end

	-- Menu-näppäin (esc) tallentaa pelin ja palaa päävalikkoon. Valikosta pääsee
	-- "Continue"-napilla takaisin juuri tähän tilanteeseen.
	if action == "menu" and phase == "down" then
		saveGame()
		music.stop()
		composer.gotoScene( "scenes.menu", { effect = "fade", time = 500 } )
		return
	end

	-- Avataan reppu inventory-näppäimellä ja pysäytetään hahmo sen ajaksi.
	if action == "inventory" and phase == "down" then
		inventoryPanel.open( dialogueGroup )
		if player and player.stop then
			player:stop()
		end
		return
	end

	if action == "interact" and phase == "down" then
		if player and player.getFacing then
			local facingX, facingY = player:getFacing()

			-- Säde alkaa hahmon keskeltä. rayCast ei ilmoita objektia, jonka sisältä
			-- säde lähtee, joten hahmo ei osu itseensä.
			local reach = 34
			local toX = player.x + facingX * reach
			local toY = player.y + facingY * reach

			local hits = physics.rayCast( player.x, player.y, toX, toY, "closest" )
			local target = hits and hits[1] and hits[1].object

			if target and target.type == "npc" then
				-- Pysäytetään hahmo ja annetaan palaute: NPC pomppaa ja soitetaan
				-- ääniefekti, jotta vuorovaikutus näkyy ja kuuluu.
				if player.stop then
					player:stop()
				end
				if target.bounce then
					target:bounce()
				end
				sfx.playInteract()

				-- Nimettömät taustahahmot ohjataan yhteiseen satunnaisrepliikkiin (npcTausta).
				local node = target.node or "npcTausta"
				dialogue.open( node, dialogueGroup, onDialogueCommand )
			elseif target and target.type == "item" then
				-- Poimitaan esine reppuun ja soitetaan ääniefekti vain, jos poiminta
				-- onnistui. Jos reppu on täynnä, esine jää kartalle eikä ääntä soiteta.
				if target:pickup() then
					sfx.playInteract()
				end
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

	-- Keskusteluikkunat piirretään scene-ryhmään, joka pysyy paikallaan ruudulla.
	dialogueGroup = sceneGroup

	-- Luetaan siirtymän mukana tulleet tiedot: mihin karttaan mennään ja minkä
	-- spawn-pisteen kohdalle pelaaja asetetaan. Ilman parametreja aloitamme kylästä.
	local sceneParams = event.params or {}

	-- Jos jatkamme tallennetusta pelistä, luetaan pelitila ja tarinan tila levyltä. Uudessa
	-- pelissä ja kentän vaihdossa savedState jää nil:ksi, jolloin edetään aivan normaalisti.
	local savedState
	if sceneParams.load then
		savedState = loadsave.load( saveFile )
		dialogue.load()
	end

	local mapName = ( savedState and savedState.mapName ) or sceneParams.mapName or "village"
	local spawnName = sceneParams.spawnName

	-- Peli alkaa alusta, kun sceneen ei tultu siirtymäportin kautta eikä
	-- tallennusta ladattu.
	newGame = sceneParams.mapName == nil and not sceneParams.load

	-- Tallennetaan kartan nimi, jotta pelitilan tallennus tietää, missä ollaan.
	currentMapName = mapName

	-- Käynnistetään fysiikka ennen kartan rakentamista, sillä kartan physics-layer
	-- luo seinien fysiikkaobjektit heti kun kartta rakennetaan. Top-down-pelissä
	-- ei ole painovoimaa, joten asetamme sen nollaan molemmilla akseleilla.
	physics.start()
	physics.setGravity( 0, 0 )

	-- Luetaan valittu kartta JSON-tiedostosta Lua-taulukoksi.
	local mapData = json.decodeFile( system.pathForFile( "maps/" .. mapName .. ".json", system.ResourceDirectory ) )

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

	-- Continue: palautetaan repun sisältö ja poimintarekisteri ennen kartan rakentamista,
	-- jotta jo poimitut esineet eivät ilmesty takaisin kentälle.
	if savedState then
		inventory.restore( savedState.inventory, savedState.collected )
		zone.restore( savedState.zones )
	end

	-- Uusi peli tyhjentää kertaalleen lauenneiden triggereiden rekisterin, jotta
	-- edellisen pelikerran laukeamiset eivät jää voimaan.
	if newGame then
		zone.reset()
	end

	-- Kerrotaan repulle ja triggereille, mitä karttaa rakennetaan. Esine-extension
	-- tarvitsee tiedon, jotta jo poimitut esineet eivät ilmesty takaisin kentälle,
	-- ja trigger-extension kirjaa laukeamiset oikean kartan kohdalle.
	inventory.setMap( mapName )
	zone.setMap( mapName )

	-- Triggerin viesti näytetään dialogi-ikkunassa pelaajan omana repliikkinä.
	function zone.onMessage( message )
		dialogue.showMonologue( message, dialogueGroup )
	end

	-- Lukitun portin viesti näytetään dialogi-ikkunassa pelaajan omana repliikkinä.
	function exit.onLocked( message )
		dialogue.showMonologue( message, dialogueGroup )
	end

	-- Ajetaan extensionit: hero korvaa "hero"-objektin pelaajalla, npc rakentaa
	-- jokaisesta "npc"-objektista oman hahmonsa, exit tekee "exit"-objekteista
	-- siirtymäportteja, item rakentaa poimittavat esineet ja zone kytkee
	-- viestitriggerit.
	map:extend( "hero", "npc", "exit", "item", "zone" )

	-- Haetaan valmis pelaajahahmo talteen. Jos kartalta puuttuu hero-objekti,
	-- kerromme siitä heti, jotta virhe huomataan kehityksen aikana.
	player = map:findObject( "hero" )
	if not player then
		print( "WARNING: the map is missing the hero object." )
	end

	-- Jos tulemme toisesta kentästä, siirretään pelaaja spawn-pisteen kohdalle.
	-- Jos nimeä vastaavaa spawn-pistettä ei löydy, jätetään pelaaja kohtaan 0,0.
	-- Näin puuttuva spawn-piste huomataan heti kehityksen aikana.
	if player and spawnName then
		local spawn = map:findObject( spawnName )
		if spawn then
			player.x, player.y = spawn.x, spawn.y
		else
			player.x, player.y = 0, 0
			print( "WARNING: spawn point \"" .. tostring( spawnName ) .. "\" was not found." )
		end
	end

	-- Continue: asetetaan pelaaja tallennettuun sijaintiin ja katsomissuuntaan. Tämä
	-- ohittaa spawn-pisteen, koska palaamme täsmälleen tallennushetken tilanteeseen.
	if player and savedState then
		player.x, player.y = savedState.playerX, savedState.playerY
		if savedState.facing then
			player:setFacing( savedState.facing.x, savedState.facing.y )
		end
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

	-- Rantatie on ruutua kapeampi, joten sen reunoille jäisi muuten mustaa. Täytetään
	-- tausta kartan takaa ruohonvärisellä suorakulmiolla, jolloin reunat sulautuvat
	-- maastoon. Muut kartat eivät tätä tarvitse: kylä täyttää ruudun ja talon
	-- musta reunus on tarkoituksellinen tyylivalinta.
	if mapName == "sideroad" then
		local edgeFill = display.newRect( sceneGroup, screen.centerX, screen.centerY, screen.width, screen.height )
		edgeFill:setFillColor( 0.62, 0.765, 0.333 )
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

		-- Soitetaan kartan mukainen taustamusiikki. Ulkokartat jakavat saman raidan,
		-- joten musiikki jatkuu katkeamatta niiden välillä ja vaihtuu vasta sisälle.
		music.playForMap( currentMapName )

		-- Näytetään uuden pelin aloitusrepliikki, joka kertoo minne suunnata.
		if newGame then
			newGame = false
			dialogue.open( "intro", dialogueGroup )
		end

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		-- Suljetaan mahdollinen avoin keskustelu tai reppu, ettei ikkuna jää roikkumaan.
		if dialogue.isOpen() then
			dialogue.close()
		end
		if inventoryPanel.isOpen() then
			inventoryPanel.close()
		end

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
	dialogueGroup = nil
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
