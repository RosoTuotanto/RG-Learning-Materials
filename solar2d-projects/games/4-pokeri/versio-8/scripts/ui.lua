local ui = {}

function ui.newInstructions()
	local text = display.newText({
		text = "Tap the deck to draw new cards.",
		x = display.contentCenterX,
		y = display.contentCenterY - 250,
		font = "assets/fonts/Micro5-Regular.ttf",
		fontSize = 40
	})
	return text
end


return ui