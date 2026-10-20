-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()

--------------------------------------------------------------------------------------
-- scene event -funktioiden ulkopuolella oleva koodi suoritetaan vain kerran, ellei
-- sceneä poisteta kokonaan composer.removeScene() avulla. Täällä kannattaa määrittää
-- yleiset muuttujat, jotta ne ovat käytettävissä kaikissa scene-funktioissa.
--------------------------------------------------------------------------------------

local canPress = false

local function menuEvent( event )
	if event.phase == "began" and canPress then
		local id = event.target.id

		if id == "start" then
			composer.gotoScene( "scenes.game", {
				time = 500,
				effect = "fade",
			} )

		elseif id == "quit" then
			native.requestExit()
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
	-- Tämä koodi ajetaan kun scene on luotu,
	-- mutta sitä ei vielä näytetä ruudulla.

	print( "scene create" )

	local paint = {
		type = "gradient",
		color1 = { 85/255, 85/255, 91/255 },
		color2 = { 10/255, 10/255, 12/255 },
		direction = "down"
	}

	local background = display.newRect( sceneGroup, screen.centerX, screen.centerY, screen.width, screen.height )
	background.fill = paint

	local logo = display.newImage( sceneGroup, "assets/images/other/Icon_256_transparent.png", screen.centerX, screen.centerY - 60 )

	local title = ui.newTitle({
		parent = sceneGroup,
		text = "Roso Noir",
		x = screen.centerX,
		y = logo.y - logo.height*0.5 - 50,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = 64,
		align = "center"
	})

	local buttonStart = ui.newTitle({
		parent = sceneGroup,
		text = "Start",
		x = screen.centerX,
		y = logo.y + logo.height*0.5 + 70,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = 40,
		align = "center"
	})
	buttonStart.id = "start"
	buttonStart:addEventListener( "touch", menuEvent )

	local buttonQuit = ui.newTitle({
		parent = sceneGroup,
		text = "Quit",
		x = screen.centerX,
		y = logo.y + logo.height*0.5 + 140,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = 40,
		align = "center"
	})
	buttonQuit.id = "quit"
	buttonQuit:addEventListener( "touch", menuEvent )
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	print( "scene show", phase )

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.
		canPress = true

		local buttonAudio = ui.newAudioButton()
	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		canPress = false


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
