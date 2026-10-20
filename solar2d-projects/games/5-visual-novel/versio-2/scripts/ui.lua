local ui = {}

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
	title.anchorX = params.anchorX or 0

	return title
end

return ui