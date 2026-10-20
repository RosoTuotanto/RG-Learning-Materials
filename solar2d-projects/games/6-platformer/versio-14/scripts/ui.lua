local ui = {}

function ui.newCounterHP( params )

	local counter = display.newGroup()
	counter.x = params.x or 0
	counter.y = params.y or 0
	params.parent:insert( counter )


	local sheet = graphics.newImageSheet( "assets/images/tiles/tilemap.png", {
		width = 18,
		height = 18,
		numFrames = 64
	} )

	-- Alapuolella olevat framet ovat laskettu yläpuolen tilemap.png:stä.
	--		start = 21 tarkoittaa, että framet alkavat 21 tilen/frame kohdalta
	--		count = 3  tarkoittaa, että otamme käyttöön 3 peräkkäistä framea
	local frames = {
		start = 21,
		count = 3,
	}

	counter.title = display.newText({
		parent = counter,
		text = "HP: ",
		x = 0,
		y = 0,
		font = "assets/fonts/munro.ttf",
		fontSize = params.fontSize,
		align = "left"
	})

	-- Luodaan tällä kertaa sprite käyttäen vain frameja.
	counter.sprite = display.newSprite( counter, sheet, frames )
	counter.sprite.x = counter.title.width
	counter.sprite.y = 0
	counter.sprite:scale( 2, 2 )


	function counter:update( hp )
		-- Pelaajan HP ja framejen numerot menevät päinvastoin.
		local frame = (2 - hp) + 1

		-- Kun kutsumme frameja counter.sprite::setFrame() funktiolla,
		-- niin se odottaa framejen alkavan 1:stä. Eli, voimme käyttää
		-- frameja 1, 2 ja 3, sillä asetimme ylempänä count = 3.
		counter.sprite:setFrame( frame )
	end

	return counter
end

function ui.newTitle( params )
	local title = display.newGroup()
	params.parent:insert( title )

	title.x = params.x or 0
	title.y = params.y or 0
	title.anchorX = params.anchorX or 0.5
	title.anchorY = params.anchorY or 0.5

	-- Lisätään text osaksi title-muuttujaa, jolloin
	-- pystymme muuttamaan sen arvoja tarvittaessa.
	title.text = display.newText({
		parent = title,
		text = params.text,
		x = 0,
		y = 0,
		font = "assets/fonts/munro.ttf",
		fontSize = params.fontSize,
		align = params.align
	})

	if type( params.rgb ) == "table" then
		title.text:setFillColor( unpack( params.rgb ) )
	else
		title.text:setFillColor( 1 )
	end

	title.shadow = display.newText({
		parent = title,
		text = params.text,
		x = 2,
		y = 2,
		font = "assets/fonts/munro.ttf",
		fontSize = params.fontSize,
		align = params.align
	})
	title.shadow:setFillColor( 0 )
	title.shadow:toBack()

	return title
end

return ui