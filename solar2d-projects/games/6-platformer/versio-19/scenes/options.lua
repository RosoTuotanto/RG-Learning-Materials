-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()
local screen = require( "scripts.core.screen" )
local ui = require( "scripts.widgets.ui" )
local widget = require( "widget" )
local loadsave = require( "scripts.core.loadsave" )
local sfx = require( "scripts.core.sfx" )

--------------------------------------------------------------------------------------
-- scene event -funktioiden ulkopuolella oleva koodi suoritetaan vain kerran, ellei
-- sceneä poisteta kokonaan composer.removeScene() avulla. Täällä kannattaa määrittää
-- yleiset muuttujat, jotta ne ovat käytettävissä kaikissa scene-funktioissa.
--------------------------------------------------------------------------------------

local buttonBack

local function buttonEvent( event )
	if ( "ended" == event.phase ) then
		local id = event.target.id
		print( id )

		if id == "back" then
			composer.hideOverlay( "fade", 250 )

		end
	end
end

local function sliderListener( event )
	-- Ajetaan alla oleva sisältö vain kun käyttäjä päästää sliderista irti.
	if event.phase == "ended" then
		print( "Slider \"" .. event.target.id .. "\" at " .. event.value .. "%" )

		loadsave.userdata[event.target.id] = event.value
		loadsave.save( loadsave.userdata, "userdata.json" )

		sfx.update()
	end
end

local function switchPress( event )
	local switch = event.target
	print( "Switch with ID '"..switch.id.."' is on: "..tostring(switch.isOn) )

	loadsave.userdata["fullscreen"] = switch.isOn
	loadsave.save( loadsave.userdata, "userdata.json" )

	-- Muutetaan pelin ikkunan koko vastaamaan fullscreen tilaa.
	if switch.isOn then
		native.setProperty( "windowMode", "fullscreen" )
	else
		native.setProperty( "windowMode", "normal" )
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

	local background = display.newRect( sceneGroup, screen.centerX, screen.centerY, screen.width, screen.height )
	background:setFillColor( 0, 0.5 )

	local window = display.newRect( sceneGroup, screen.centerX, screen.centerY, 600, 600 )
	window:setFillColor( 0, 0.9 )

	local title = ui.newTitle({
		parent = sceneGroup,
		text = "Options",
		fontSize = 48,
		rgb = { 1, 1, 1 },
	})
	title.x = screen.centerX
	title.y = window.y - window.height*0.5 + title.height*0.5 + 10

	-- Luodaan äänenvoimakkuuden sliderit.
	local sliderMasterVolume = widget.newSlider(
		{
			x = display.contentCenterX,
			y = 180,
			id = "masterVolume",
			width = 320,
			value = loadsave.userdata["masterVolume"],
			listener = sliderListener
		}
	)
	sceneGroup:insert( sliderMasterVolume )

	local titleMasterVolume = ui.newTitle({
		parent = sceneGroup,
		text = "Master Volume",
		fontSize = 32,
		rgb = { 1, 1, 1 },
	})
	titleMasterVolume.x = screen.centerX
	titleMasterVolume.y = sliderMasterVolume.y - sliderMasterVolume.height - 6


	local sliderMusicVolume = widget.newSlider(
		{
			x = display.contentCenterX,
			y = sliderMasterVolume.y + sliderMasterVolume.height + 70,
			id = "musicVolume",
			width = 320,
			value = loadsave.userdata["musicVolume"],
			listener = sliderListener
		}
	)
	sceneGroup:insert( sliderMusicVolume )

	local titleMusicVolume = ui.newTitle({
		parent = sceneGroup,
		text = "Music Volume",
		fontSize = 32,
		rgb = { 1, 1, 1 },
	})
	titleMusicVolume.x = screen.centerX
	titleMusicVolume.y = sliderMusicVolume.y - sliderMusicVolume.height - 6


	local sliderSFXVolume = widget.newSlider(
		{
			x = display.contentCenterX,
			y = sliderMusicVolume.y + sliderMusicVolume.height + 70,
			id = "sfxVolume",
			width = 320,
			value = loadsave.userdata["sfxVolume"],
			listener = sliderListener
		}
	)
	sceneGroup:insert( sliderSFXVolume )

	local titleSFXVolume = ui.newTitle({
		parent = sceneGroup,
		text = "SFX Volume",
		fontSize = 32,
		rgb = { 1, 1, 1 },
	})
	titleSFXVolume.x = screen.centerX
	titleSFXVolume.y = sliderSFXVolume.y - sliderSFXVolume.height - 6


	local fullscreenCheckbox = widget.newSwitch(
		{
			x = 560,
			y = sliderSFXVolume.y + sliderSFXVolume.height + 50,
			style = "checkbox",
			id = "fullscreen",
			onPress = switchPress,
			initialSwitchState = loadsave.userdata["fullscreen"],
		}
	)
	sceneGroup:insert( fullscreenCheckbox )

	local titleFullscreen = ui.newTitle({
		parent = sceneGroup,
		text = "Fullscreen",
		fontSize = 32,
		rgb = { 1, 1, 1 },
		anchorX = 1,
	})
	titleFullscreen.x = fullscreenCheckbox.x - fullscreenCheckbox.width - titleFullscreen.width*0.5 - 10
	titleFullscreen.y = fullscreenCheckbox.y

	buttonBack = widget.newButton(
		{
			x = display.contentCenterX,
			y = window.y + window.height*0.5 - 40,
			id = "back",
			label = "Back",
			labelAlign = "center",
			labelColor = { default={ 0.9 }, over={ 1 } },
			onEvent = buttonEvent,
			fontSize = 40,
			font = "assets/fonts/munro.ttf",
			shape = "rect",
			fillColor = { default={ 0, 0.7 }, over={ 0, 0.9 } },
			isEnabled = false,
		}
	)
	sceneGroup:insert( buttonBack )
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

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.
		buttonBack:setEnabled( false )

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
