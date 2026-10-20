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

--------------------------------------------------------------------------------------
-- Muuttujat

-- Painetun ympyrän väri, tai nil jos overlay suljettiin "Close"-tekstistä.
local ballColor

--------------------------------------------------------------------------------------
-- Funktiot

-- Suljetaan overlay. Väri (jos annettu) välitetään game scenelle vasta hide-vaiheessa.
local function closeOverlay( color )
	ballColor = color
	composer.hideOverlay( "fade", 250 )
end

local function closeTouch( event )
	if event.phase == "began" then
		closeOverlay( nil )
	end

	return true
end

local function ballTouch( event )
	if event.phase == "began" then
		closeOverlay( event.target.ballColor )
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

	-- Musta, osittain läpinäkyvä nelikulmio, joka peittää koko ruudun.
	local background = display.newRect( sceneGroup, screen.centerX, screen.centerY, screen.width, screen.height )
	background:setFillColor( 0, 0.75 )

	-- "Close"-teksti vasempaan yläreunaan game scenen "Back"-napin viereen, jotta ne eivät mene päällekkäin.
	local buttonClose = ui.newTitle({
		parent = sceneGroup,
		text = "Close",
		x = screen.minX + 140,
		y = screen.minY + 22,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = 32,
		align = "left"
	})
	buttonClose:addEventListener( "touch", closeTouch )

	-- Kaksi ympyrää ruudun keskelle. Jokainen tietää oman värinsä.
	local blueBall = display.newCircle( sceneGroup, screen.centerX - 90, screen.centerY, 60 )
	blueBall:setFillColor( 0.2, 0.4, 1 )
	blueBall.ballColor = "blue"
	blueBall:addEventListener( "touch", ballTouch )

	local yellowBall = display.newCircle( sceneGroup, screen.centerX + 90, screen.centerY, 60 )
	yellowBall:setFillColor( 1, 0.85, 0.1 )
	yellowBall.ballColor = "yellow"
	yellowBall:addEventListener( "touch", ballTouch )
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.
		-- Nollataan valinta aina kun overlay avataan uudelleen.
		ballColor = nil

	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.

	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene on piilotettu.
		-- Kerrotaan alla olevalle game scenelle mitä ympyrää painettiin.
		local parent = event.parent
		if parent and parent.resumeAfterOverlay then
			parent:resumeAfterOverlay( ballColor )
		end
	end
end


-- destroy: kutsutaan kun scene halutaan poistaa kokonaan.
-- Täällä siivotaan kaikki objektit ja resurssit.
function scene:destroy( event )
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
