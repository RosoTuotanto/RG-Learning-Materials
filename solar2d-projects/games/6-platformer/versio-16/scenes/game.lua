-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )
local ponytiled = require( "com.ponywolf.ponytiled" )
local json = require( "json" )
local playerModule = require( "scripts.player" )
local spikesModule = require( "scripts.spikes" )
local trampolineModule = require( "scripts.trampoline" )
local heartModule = require( "scripts.heart" )
local coinModule = require( "scripts.coin" )
local goalModule = require( "scripts.goal" )
local controls = require( "scripts.controls" )
local loadsave = require( "scripts.loadsave" )

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 9.8 )
-- physics.setDrawMode( "hybrid" )  -- Vaihtoehdot: "normal", "debug", "hybrid"

--------------------------------------------------------------------------------------
-- scene event -funktioiden ulkopuolella oleva koodi suoritetaan vain kerran, ellei
-- sceneä poisteta kokonaan composer.removeScene() avulla. Täällä kannattaa määrittää
-- yleiset muuttujat, jotta ne ovat käytettävissä kaikissa scene-funktioissa.
--------------------------------------------------------------------------------------

local player, counterHP, levelBorder
local sceneGroup

local function menuClose()
	display.remove( ui.menuGroup )
	ui.menuGroup = nil
	composer.hideOverlay( 0 )

	physics.start()
	transition.resumeAll()
	timer.resumeAll()
end

local function menuOpen( menuType )
	physics.pause()
	transition.pauseAll()
	timer.pauseAll()

	-- Lisätään viittauksia menun tilaan.
	ui.menuType = menuType
	ui.callback = menuClose

	ui.newMenu( sceneGroup, menuType )
end

local function movePlayer( vx, vy )
	player:move( vx, vy )
end

local function keyPressed( action, phase )
	-- print( "action", action, "phase", phase )

	if action == "jump" then
		player:jump( phase == "down" )

	elseif action == "menu" then
		if phase == "down" then
			if ui.menuGroup then
				if ui.menuType == "pause" then
					menuClose()
				end
			else
				menuOpen( "pause" )
			end
		end
	end
end

local function onCollision( self, event )
	-- print( "collided with", event.other.id, "phase", event.phase )
	local phase = event.phase
	local id = event.other.id

	-- Jos pelaaja on kuollut, ei käsitellä muita törmäyksiä.
	if player.isDead then
		return
	end

	if phase == "began" then
		if id == "platform" or id == "rope" then
			player:resetJumpCount()

			if id == "rope" then
				player:touchRope( true )
			end

		elseif id == "trampoline" then
			-- Tallennetaan viittaus viimeksi kosketettuun trampoliiniin.
			player.nearbyTrampoline = event.other

		elseif id == "heart" or id == "coin" then
			event.other:collect()

			if id == "heart" then
				player:addHP( 1 )
				counterHP:update( player.currentHP )

			elseif id == "coin" then
				-- Kasvatetaan kerättyjen kolikoiden määrää ja tallennetaan se.
				loadsave.userdata.coinsCollected = loadsave.userdata.coinsCollected + 1
				loadsave.save( loadsave.userdata, "userdata.json" )

				-- TODO: Päivitä mahdollinen kolikkojen näyttö käyttöliittymässä.

			end

		elseif id == "goal" then
			event.other:complete()
			player.isDead = true
			controls.stop()
			menuOpen( "complete" )

		elseif id == "spikes" or id == "levelBorder" or event.other.isEnemy then
			local isBorder = (id == "levelBorder")
			local damage = 1
			if isBorder then
				damage = player.maxHP
			end
			player:takeDamage( damage, isBorder )
			counterHP:update( player.currentHP )

			if player.isDead then
				controls.stop()
				menuOpen( "gameover" )
			end
		end

	elseif phase == "ended" then
		if id == "rope" then
			player:touchRope( false )

		elseif id == "trampoline" then
			-- Poistetaan viittaus vain, jos kyseessä on sama trampoliini.
			if player.nearbyTrampoline and player.nearbyTrampoline == event.other then
				player.nearbyTrampoline = nil
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
	sceneGroup = self.view
	-- Tämä koodi ajetaan kun scene on luotu,
	-- mutta sitä ei vielä näytetä ruudulla.

	-- Haetaan ladattava kenttä event.params.level muuttujasta.
	-- Jos kenttää ei ole määritetty, asetetaan oletukseksi "tutorial.json".
	local level = event.params and event.params.level or "tutorial.json"
	ui.currentLevel = level
	print( "Ladataan kenttä: " .. level )


	-- Ladataan kentän data JSON-tiedostosta.
	local mapData = json.decodeFile(system.pathForFile("assets/" .. level, system.ResourceDirectory))
	-- Kerrotaan ponytiled-kirjastolle, mistä kenttä tulee ladata.
	local map = ponytiled.new(mapData, "assets")
	sceneGroup:insert( map )
	map.x = display.contentCenterX - map.designedWidth/2
	map.y = display.contentCenterY - map.designedHeight/2

	------------------------------------------------------------------------------
	-- Luodaan dynaamiset hahmot ja objektit:

	-- Haetaan kentästä "level" layeri, eli display group, josta löydämme peliobjektit.
	local levelGroup = map:findLayer( "level" )

	player = map:getFirstTile( "id", "player" )
	player = playerModule.new( levelGroup, player )
	player.collision = onCollision
	player:addEventListener( "collision" )

	local spikes = map:getAllTiles( "id", "spikes" )
	for i = 1, #spikes do
		spikesModule.new( levelGroup, spikes[i] )
	end

	local trampolines = map:getAllTiles( "id", "trampoline" )
	for i = 1, #trampolines do
		trampolineModule.new( levelGroup, trampolines[i] )
	end

	local hearts = map:getAllTiles( "id", "heart" )
	for i = 1, #hearts do
		heartModule.new( levelGroup, hearts[i] )
	end

	local coins = map:getAllTiles( "id", "coin" )
	for i = 1, #coins do
		coinModule.new( levelGroup, coins[i] )
	end

	local flag = map:getFirstTile( "id", "goal" )
	goalModule.new( levelGroup, flag )

	counterHP = ui.newCounterHP({
		parent = sceneGroup,
		x = screen.minX + 40,
		y = screen.minY + 24,
		fontSize = 24,
	} )

	levelBorder = display.newRect(
		map,
		screen.centerX - map.x,
		screen.centerY - map.y,
		map.designedWidth,
		map.designedHeight
	)

	levelBorder.fill = { 0, 0 }
	levelBorder.strokeWidth = 4
	levelBorder:setStrokeColor( 1, 0, 0 )
	levelBorder.id = "levelBorder"

	physics.addBody( levelBorder, "static", {
		isSensor = true,
		chain = {
			-map.designedWidth/2, -map.designedHeight/2,
			map.designedWidth/2, -map.designedHeight/2,
			map.designedWidth/2, map.designedHeight/2,
			-map.designedWidth/2, map.designedHeight/2
		},
		connectFirstAndLastChainVertex = true
	} )
end

-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.
		controls.start( movePlayer, keyPressed )

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		controls.stop()

	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene on piilotettu.


	end
end


-- destroy: kutsutaan kun scene halutaan poistaa kokonaan.
-- Täällä siivotaan kaikki objektit ja resurssit.
function scene:destroy( event )
	sceneGroup = self.view
	-- Ajetaan juuri ennen kuin scene tuhotaan.
	ui.menuGroup = nil
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
