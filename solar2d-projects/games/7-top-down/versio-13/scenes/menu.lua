-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )
local widget = require( "widget" )
local loadsave = require( "scripts.loadsave" )
local dialogue = require( "scripts.dialogue" )
local inventory = require( "scripts.inventory" )

-- Pelitilan tallennustiedosto. Sama nimi on käytössä game-scenessä (scenes/game.lua).
local saveFile = "gamesave.json"

--------------------------------------------------------------------------------------
-- scene event -funktioiden ulkopuolella oleva koodi suoritetaan vain kerran, ellei
-- sceneä poisteta kokonaan composer.removeScene()-funktion avulla. Täällä kannattaa määrittää
-- yleiset muuttujat, jotta ne ovat käytettävissä kaikissa scene-funktioissa.
--------------------------------------------------------------------------------------

local buttonContinue
local buttonPlay
local buttonOptions
local buttonExit

-- Function to handle button events
local function menuListener( event )
	if event.phase == "ended" then
		local id = event.target.id
		-- print( id )

		if id == "continue" then
			-- Jatketaan tallennetusta pelistä. Game-scene lataa tilan load-parametrilla.
			composer.gotoScene( "scenes.game", { effect = "fade", time = 500, params = { load = true } } )

		elseif id == "play" then
			-- Uusi peli: tyhjennetään muistissa oleva reppu, poistetaan pelitilan tallennus ja
			-- aloitetaan tarina alusta, jotta seikkailu alkaa täysin puhtaalta pöydältä
			-- (myös silloin, kun edellinen peli on juuri pelattu).
			inventory.reset()
			loadsave.delete( saveFile )
			dialogue.init()
			-- Aloitusesineet lisätään tyhjennettyyn reppuun heti uudelleen.
			inventory.addStartingItems()
			composer.gotoScene( "scenes.game", { effect = "fade", time = 500 } )

		elseif id == "options" then
			composer.showOverlay( "scenes.options", {
				isModal = true,
				effect = "fade",
				time = 250
			} )

		elseif id == "exit" then
			native.requestExit()

		end
	end
	return true
end

--------------------------------------------------------------------------------------
-- scene event -funktiot:
--------------------------------------------------------------------------------------

-- create: kutsutaan kun scene luodaan ensimmäistä kertaa,
-- tai jos se on poistettu ja sitä luodaan uudelleen.
function scene:create( event )
	local sceneGroup = self.view
	-- Tämä koodi ajetaan kun scene on luotu,
	-- mutta sitä ei vielä näytetä ruudulla.

	-- Yksinkertainen tausta. Korvataan myöhemmin pelin omalla otsikkokuvalla.
	local background = display.newRect( sceneGroup, screen.centerX, screen.centerY, screen.width, screen.height )
	background:setFillColor( 0.08, 0.1, 0.14 )

	local title = ui.newTitle({
		parent = sceneGroup,
		text = "top-down",
		fontSize = 48,
		rgb = { 1, 1, 1 },
	})
	title.x = screen.centerX
	title.y = screen.minY + title.height*0.5 + 10

	-- Näytetään Continue-nappi vain, jos tallennettu peli on olemassa.
	buttonContinue = nil
	local hasSave = loadsave.load( saveFile ) ~= nil

	-- Neljä nappia mahtuu ruudulle, kun aloitamme hieman ylempää kuin kolmella napilla.
	local firstButtonY = hasSave and 300 or 360

	if hasSave then
		buttonContinue = widget.newButton(
			{
				x = display.contentCenterX,
				y = firstButtonY,
				id = "continue",
				label = "Continue",
				labelAlign = "center",
				labelColor = { default={ 0.9 }, over={ 1 } },
				onEvent = menuListener,
				fontSize = 48,
				font = "assets/fonts/munro.ttf",
				shape = "rect",
				fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
				isEnabled = false,
			}
		)
		sceneGroup:insert( buttonContinue )
	end

	-- Luodaan menun napit. Play aloittaa aina uuden pelin.
	buttonPlay = widget.newButton(
		{
			x = display.contentCenterX,
			y = buttonContinue and ( buttonContinue.y + buttonContinue.height + 20 ) or firstButtonY,
			id = "play",
			label = "Play",
			labelAlign = "center",
			labelColor = { default={ 0.9 }, over={ 1 } },
			onEvent = menuListener,
			fontSize = 48,
			font = "assets/fonts/munro.ttf",
			shape = "rect",
			fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
			isEnabled = false,
		}
	)
	sceneGroup:insert( buttonPlay )

	buttonOptions = widget.newButton(
		{
			x = display.contentCenterX,
			y = buttonPlay.y + buttonPlay.height + 20,
			id = "options",
			label = "Options",
			labelAlign = "center",
			labelColor = { default={ 0.9 }, over={ 1 } },
			onEvent = menuListener,
			fontSize = 48,
			font = "assets/fonts/munro.ttf",
			shape = "rect",
			fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
			isEnabled = false,
		}
	)
	sceneGroup:insert( buttonOptions )

	buttonExit = widget.newButton(
		{
			x = display.contentCenterX,
			y = buttonOptions.y + buttonOptions.height + 20,
			id = "exit",
			label = "Exit",
			labelAlign = "center",
			labelColor = { default={ 0.9 }, over={ 1 } },
			onEvent = menuListener,
			fontSize = 48,
			font = "assets/fonts/munro.ttf",
			shape = "rect",
			fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
			isEnabled = false,
		}
	)
	sceneGroup:insert( buttonExit )
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.
		if buttonContinue then
			buttonContinue:setEnabled( true )
		end
		buttonPlay:setEnabled( true )
		buttonOptions:setEnabled( true )
		buttonExit:setEnabled( true )

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		if buttonContinue then
			buttonContinue:setEnabled( false )
		end
		buttonPlay:setEnabled( false )
		buttonOptions:setEnabled( false )
		buttonExit:setEnabled( false )

	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene on piilotettu.


	end
end


-- destroy: kutsutaan kun scene halutaan poistaa kokonaan.
-- Täällä siivotaan kaikki objektit ja resurssit.
function scene:destroy( event )
	local sceneGroup = self.view
	-- Ajetaan juuri ennen kuin scene tuhotaan.
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
