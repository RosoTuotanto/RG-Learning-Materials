-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )
local widget = require( "widget" )

--------------------------------------------------------------------------------------
-- scene event -funktioiden ulkopuolella oleva koodi suoritetaan vain kerran, ellei
-- sceneä poisteta kokonaan composer.removeScene() avulla. Täällä kannattaa määrittää
-- yleiset muuttujat, jotta ne ovat käytettävissä kaikissa scene-funktioissa.
--------------------------------------------------------------------------------------

local buttonPlay
local buttonOptions
local buttonExit

-- Function to handle button events
local function menuListener( event )
	if event.phase == "ended" then
		local id = event.target.id
		-- print( id )

		if id == "play" then
			composer.gotoScene( "scenes.levelSelect", { effect = "fade", time = 500 } )

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

	local background = display.newImage(
		sceneGroup, "assets/images/backgrounds/menu.png",
		screen.centerX,
		screen.centerY
	)

	-- Skaalataan taustakuva peittämään koko ruutu.
	local scale = math.max( screen.width/background.width, screen.height/background.height )
	background.xScale, background.yScale = scale, scale

	local title = ui.newTitle({
		parent = sceneGroup,
		text = "Platformer",
		fontSize = 48,
		rgb = { 1, 1, 1 },
	})
	title.x = screen.centerX
	title.y = screen.minY + title.height*0.5 + 10

	-- Luodaan menun napit.
	buttonPlay = widget.newButton(
		{
			x = display.contentCenterX,
			y = 360,
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
