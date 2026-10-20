-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )
local weaver = require( "scripts.spyricStoryWeaver" )
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

local storyName = "Roso Noir"
local canPress = false
local sfxClick = audio.loadSound( "assets/sfx/click.wav" )

local characters, text, background = {}, {}
local nodeIndex, node

local sceneGroup

--------------------------------------------------------------------------------------
-- Funktiot

local getNode

-- Pelaaja painaa linkkiä ja siirtyy seuraavaan nodeen.
local function touchLink( event )
	if event.phase == "began" and canPress then
		canPress = false
		getNode( event.target.id )
	end
	return true
end

-- Poistetaan kaikki ruudulla olevat tekstit ja tyhjennetään text-taulukko.
local function clearText()
	for i = 1, #text do
		display.remove( text[i] )
		text[i] = nil
	end
end

-- Käydään valitun noden (passagen) sisältöä järjestyksessä läpi.
local function getContent()
	-- Varmistetaan, että node on olemassa.
	if nodeIndex > #node then
		return
	end

	-- Aloitetaan loop siitä mihin viimeksi jäätiin.
	for i = nodeIndex, #node do
		print( i, table.concat( node[i], ", " ) )
		nodeIndex = nodeIndex + 1

		local command = node[i][1]
		if command == "img" or command == "del" then
			display.remove( background )

			if command == "img" then
				background = ui.newBackground( sceneGroup, node[i][2] )
			end

		elseif command == "character" then
			-- Käytetään characters-taulukkoa hahmojen hallintaan.
			local name = node[i][3]

			-- Tarkistetaan piilotetaanko vai näytetäänkö hahmo.
			if node[i][2] == "hide" then
				display.remove( characters[name] )
				characters[name] = nil
			else
				-- Jos hahmoa ei ole vielä luotu, luodaan se.
				if not characters[name] then
					-- Lasketaan hahmon sijainti ja annetaan se ui-moduulille.
					local x = node[i].x or screen.centerX
					local yBG = background and (background.y + background.height * 0.5) or nil
					local y = node[i].y or yBG or screen.centerY

					characters[name] = ui.newCharacter( sceneGroup, name, x, y, node[i].xScale )
				end
			end

		elseif command == "text" or command == "link" then
			local x, y = screen.centerX, screen.centerY + 190

			if command == "text" then
				-- Poistetaan vanhat tekstit ennen uuden luontia.
				clearText()
			else
				-- Jos luomme linkin, sijoitetaan se edellisen tekstin alle.
				if #text > 0 then
					y = text[#text].y + text[#text].height + 16
				end
			end

			text[#text+1] = ui.newText({
				parent = sceneGroup,
				text = node[i][2],
				x = x,
				y = y
			})

			if command == "link" then
				text[#text]:setFillColor( 230/255, 170/255, 25/255 )
				text[#text]:addEventListener( "touch", touchLink )
				text[#text].id = node[i][3]
			end

			if node[i+1] and node[i+1][1] ~= "link" then
				break
			end

		elseif command == "overlay" then
			-- Avataan overlay scene game scenen päälle ja pysäytetään noden
			-- luku, kunnes overlay sulkeutuu ja kutsuu resumeAfterOverlay:ta.
			canPress = false
			composer.showOverlay( "scenes.overlay", {
				isModal = true,
				effect = "fade",
				time = 250
			} )
			break
		end
	end
end

-- Ladataan uusi node (passage) ja nollataan nodeIndex laskuri.
function getNode( nodeName )
	clearText()

	for name, _ in pairs( characters ) do
		display.remove( characters[name] )
		characters[name] = nil
	end

	node = weaver.getNode( nodeName, storyName )
	nodeIndex = 1

	getContent()
	canPress = true
end

local function sensorEvent( event )
	if event.phase == "began" and canPress then
		audio.play( sfxClick )
		getContent()
	end
end

-- Overlay scene kutsuu tätä sulkeutuessaan. ballColor on painetun ympyrän väri,
-- tai nil jos overlay suljettiin "Close"-tekstistä ilman valintaa.
function scene:resumeAfterOverlay( ballColor )
	if ballColor then
		-- Näytetään valinta samalla ui.newText-funktiolla kuin hahmojen puhe.
		clearText()

		text[#text+1] = ui.newText({
			parent = sceneGroup,
			text = "I pressed " .. ballColor,
			x = screen.centerX,
			y = screen.centerY + 190
		})
	end

	-- Jatketaan noden lukua, jolloin linkkiteksti tulee näkyviin.
	getContent()
	canPress = true
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

	-- Ladataan tarina.
	weaver.initStory({
		name = storyName,
		source = "data/Roso Noir.json",
	})

	-- Luodaan näkymätön sensori, jota koskettamalla pelaaja voi hallita peliä.
	local touchSensor = display.newRect( sceneGroup, screen.centerX, screen.centerY, screen.width, screen.height )
	touchSensor:addEventListener( "touch", sensorEvent )
	touchSensor.isVisible = false
	touchSensor.isHitTestable = true

	-- Ladataan ensimmäinen node (passage).
	getNode( "Exterior" )

	-- Luodaan nappi, millä pelaaja voi palata menu sceneen.
	local buttonBack = ui.newTitle({
		parent = sceneGroup,
		text = "Back",
		x = screen.minX + 44,
		y = screen.minY + 22,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = 32,
		align = "left"
	})

	buttonBack:addEventListener( "touch", function( event )
		if event.phase == "began" and canPress then
			composer.gotoScene( "scenes.menu", {
				time = 500,
				effect = "fade",
			} )
		end

		return true
	end )
end


-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local phase = event.phase
	sceneGroup = self.view

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene tulee näkyviin.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.
		canPress = true

	end
end


-- hide: kutsutaan kun näkyvä scene halutaan piilottaa.
function scene:hide( event )
	local phase = event.phase
	sceneGroup = self.view

	if ( phase == "will" ) then
		-- Ajetaan ennen kuin scene katoaa näkyvistä.


	elseif ( phase == "did" ) then
		-- Ajetaan heti kun scene on piilotettu.
		canPress = false

	end
end


-- destroy: kutsutaan kun scene halutaan poistaa kokonaan.
-- Täällä siivotaan kaikki objektit ja resurssit.
function scene:destroy( event )
	sceneGroup = self.view
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
