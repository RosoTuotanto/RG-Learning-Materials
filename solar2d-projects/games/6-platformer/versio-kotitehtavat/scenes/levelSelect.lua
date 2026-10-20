-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()
local screen = require( "scripts.core.screen" )
local ui = require( "scripts.widgets.ui" )
local widget = require( "widget" )
local levelData = require( "data.levels" )
local loadsave = require( "scripts.core.loadsave" )

--------------------------------------------------------------------------------------
-- scene event -funktioiden ulkopuolella oleva koodi suoritetaan vain kerran, ellei
-- sceneä poisteta kokonaan composer.removeScene() avulla. Täällä kannattaa määrittää
-- yleiset muuttujat, jotta ne ovat käytettävissä kaikissa scene-funktioissa.
--------------------------------------------------------------------------------------

local buttonLevel = {}
local buttonBack
local coinTotalIndicator

local function buttonEvent( event )
	if ( "ended" == event.phase ) then
		local id = event.target.id
		print( id )

		if id == "back" then
			composer.gotoScene( "scenes.menu", { effect = "fade", time = 500 } )

		else
			-- Jos pelaaja ei painanut "back" nappia, niin event.target.id
			-- sisältää ladattavan kentän tunnuksen.
			composer.gotoScene( "scenes.game", { effect = "fade", time = 500,
				params = {
					level = id
				}
			} )
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
		text = "Level Select",
		fontSize = 48,
		rgb = { 1, 1, 1 },
	})
	title.x = screen.centerX
	title.y = screen.minY + title.height*0.5 + 10

	-- Kolikkoindikaattori, joka näyttää eri pelikierrosten aikana kerätyt kolikot yhteensä.
	-- Kokonaismäärä luetaan userdata.json-tiedostosta ladatusta loadsave.userdatasta.
	coinTotalIndicator = ui.newCounterCoins({
		parent = sceneGroup,
		x = screen.minX + 30,
		y = screen.minY + 40,
		fontSize = 28,
		text = tostring( loadsave.userdata.coinsCollected ),
	} )

	buttonBack = widget.newButton(
		{
			x = display.contentCenterX,
			y = screen.maxY - 50,
			id = "back",
			label = "Back to Menu",
			labelAlign = "center",
			labelColor = { default={ 0.9 }, over={ 1 } },
			onEvent = buttonEvent,
			fontSize = 40,
			font = "assets/fonts/munro.ttf",
			width = 240,
			shape = "rect",
			fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
			isEnabled = false,
		}
	)
	sceneGroup:insert( buttonBack )

	for i = 1, #levelData do
		buttonLevel[i] = widget.newButton(
			{
				x = screen.centerX,
				y = 150 + (i-1) * 80,
				id = levelData[i].filename,
				label = levelData[i].label,
				labelAlign = "center",
				labelColor = { default={ 0.9 }, over={ 1 } },
				onEvent = buttonEvent,
				fontSize = 36,
				font = "assets/fonts/munro.ttf",
				width = 300,
				shape = "rect",
				fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
				isEnabled = false,
			}
		)
		sceneGroup:insert( buttonLevel[i] )
	end
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.
		buttonBack:setEnabled( true )
		for i = 1, #buttonLevel do
			buttonLevel[i]:setEnabled( true )
		end

		-- Päivitetään kokonaismäärä aina, kun palataan tähän näkymään.
		coinTotalIndicator:setText( tostring( loadsave.userdata.coinsCollected ) )

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		buttonBack:setEnabled( false )
		for i = 1, #buttonLevel do
			buttonLevel[i]:setEnabled( false )
		end


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
