local ui = {}

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