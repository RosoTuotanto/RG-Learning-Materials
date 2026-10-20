local ui = {}

local screen = require( "scripts.screen" )

-- Muuttuja, joka kertoo onko audio-nappi jo luotu.
local audioButtonCreated = false

-- Luodaan uusi audio-nappi.
function ui.newAudioButton()

	if audioButtonCreated then
		return
	end

	local fillOn = {
		type = "image",
		filename = "assets/images/other/music_on.png"
	}

	local fillOff = {
		type = "image",
		filename = "assets/images/other/music_off.png"
	}

	local button = display.newRect( screen.maxX - 32, screen.minY + 32, 64, 64 )
	-- Äänet ovat alkuun päällä, paitsi developer-tilassa, jossa ne on vaimennettu.
	button.isActive = not _G.developerMode
	button.fill = button.isActive and fillOn or fillOff

	-- Ladataan taustamusiikki streaminä.
	local bgm = audio.loadStream( "assets/music/detective-noir.mp3" )

	-- Master-volume riippuu developer-tilasta.
	local masterVolume = _G.developerMode and 0 or 0.5
	audio.setVolume( masterVolume )

	-- Hiljennetään taustamusiikin kanava erikseen.
	audio.setVolume( 0.5, { channel=1 } )

	-- Soitetaan taustamusiikki ikuisella loopilla.
	audio.play( bgm, {
		channel = 1,
		loops = -1,
		fadein = 3000
	})

	-- Lisätään nappiin touch event listener.
	button:addEventListener( "touch", function( event )
		if event.phase == "began" then
			local target = event.target

			-- Käännetään muuttujan arvo ympäri "not"-operaattorilla.
			target.isActive = not target.isActive

			-- Äänet takaisin päälle.
			if target.isActive then
				audio.setVolume( 0.5 )
				audio.resume( 1 )
				button.fill = fillOn

			-- Äänet pois päältä.
			else
				audio.setVolume( 0 )
				audio.pause( 1 )
				button.fill = fillOff
			end
		end

		return true
	end )

	audioButtonCreated = true
end

function ui.newTitle( params )
	local title = display.newGroup()
	params.parent:insert( title )

	-- Lisätään text osaksi title-muuttujaa, jolloin
	-- pystymme muuttamaan sen arvoja tarvittaessa.
	title.text = display.newText({
		parent = title,
		text = params.text,
		x = params.x,
		y = params.y,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = params.fontSize,
		align = params.align
	})
	title.text:setFillColor( 248/255, 240/255, 219/255 )

	title.shadow = display.newText({
		parent = title,
		text = params.text,
		x = params.x + 2,
		y = params.y + 2,
		font = "assets/fonts/Roboto/Roboto-Bold.ttf",
		fontSize = params.fontSize,
		align = params.align
	})
	title.shadow:setFillColor( 0 )
	title.shadow:toBack()

	title.anchorX = params.anchorX or 0
	title.anchorY = params.anchorY or 0

	return title
end

return ui