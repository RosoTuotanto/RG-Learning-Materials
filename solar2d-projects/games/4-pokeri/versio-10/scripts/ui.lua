local ui = {}

function ui.newInstructions( parent )
	local text = display.newText({
		parent = parent,
		text = "Tap the deck to draw new cards.",
		x = display.contentCenterX,
		y = display.contentCenterY - 250,
		font = "assets/fonts/Micro5-Regular.ttf",
		fontSize = 40
	})
	return text
end


return ui