local ui = {}

local screen = require( "scripts.screen" )
local composer = require( "composer" )

local function menuEvent( event )
	if event.phase == "ended" then
		local id = event.target.id
		print( id )

		if id == "continue" then
			ui.callback()

		elseif id == "restart" then
			composer.gotoScene( "scenes.reloadScene", {
				effect = "fade",
				time = 250,
				params = {
					level = ui.currentLevel
				}
			} )

		elseif id == "levelSelect" then
			composer.gotoScene( "scenes.levelSelect", { effect = "fade", time = 500 } )

		elseif id == "options" then
			composer.showOverlay( "scenes.options", {
				isModal = true,
				effect = "fade",
				time = 250
			} )

		end
	end
	return true
end

function ui.newMenu( parent, menuType )

	-- Jos menu on jo auki, ei avata uutta.
	if ui.menuGroup then
		return
	end

	-- Lisäämällä menuGroup muuttujan ui-taulukkoon, pystymme
	-- tarkistamaan myös game scenestä käsin onko menu auki.
	ui.menuGroup = display.newGroup()
	parent:insert( ui.menuGroup )

	local background = display.newRect( ui.menuGroup, screen.centerX, screen.centerY, screen.width, screen.height )
	background:setFillColor( 0, 0.75 )

	local windowTitle, windowHeight

	local buttonList = {
		{ label = "Restart Level", id = "restart" },
		{ label = "Back to Level Select", id = "levelSelect" },
		{ label = "Options", id = "options" }
	}

	-- Muutetaan menun visuaalisia asetuksia menun tyypin mukaan.
	if menuType == "pause" then
		windowTitle = "Game Paused."
		windowHeight = 480
		-- Pause-menuun lisätään yksi ylimääräinen nappi.
		buttonList[#buttonList+1] = { label = "Continue", id = "continue" }

	else
		windowHeight = 400

		if menuType == "gameover" then
			windowTitle = "Gameover!"
		elseif menuType == "complete" then
			windowTitle = "Level Complete!"
		end
	end

	local window = display.newRect( ui.menuGroup, screen.centerX, screen.centerY, 600, windowHeight )
	window:setFillColor( 0, 0.85 )

	local heading = display.newText({
		parent = ui.menuGroup,
		text = windowTitle,
		x = window.x,
		y = window.y - window.height*0.5 + 30,
		font = "assets/fonts/munro.ttf",
		fontSize = 60,
		align = "left"
	})
	heading.anchorY = 0

	-- Luodaan napit käänteisesti loopissa, jolloin taulukon viimeinen nappi luodaan
	-- ikkunan pohjalle ensimmäisenä. Näin napit sijoittuvat ikkunaan dynaamisesti.
	for i = #buttonList, 1, -1 do

		local button = display.newText({
			parent = ui.menuGroup,
			text = buttonList[i].label,
			x = window.x,
			y = window.y + window.height*0.5 - 60*(#buttonList-i) - 40,
			font = "assets/fonts/munro.ttf",
			fontSize = 46,
			align = "left"
		})
		button.id = buttonList[i].id
		button.anchorY = 1

		button:addEventListener( "touch", menuEvent )
	end
end

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