local ui = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local buttonSettings = layout.button

--------------------------------------------------------------------------------------
-- Public functions

function ui.setColor( object, color )
	object:setFillColor( color[1], color[2], color[3] )
end

-- params: parent, x, y, label, onPress, plus optional width, height and fontSize that default to layout.button.
function ui.newButton( params )
	local button = display.newGroup()
	button.x = params.x
	button.y = params.y
	params.parent:insert( button )

	local width = params.width or buttonSettings.width
	local height = params.height or buttonSettings.height

	local background = display.newRoundedRect( button, 0, 0, width, height, buttonSettings.cornerRadius )
	ui.setColor( background, palette.buttonFill )
	background.strokeWidth = buttonSettings.strokeWidth
	background:setStrokeColor( palette.buttonBorder[1], palette.buttonBorder[2], palette.buttonBorder[3] )

	local label = display.newText({
		parent = button,
		text = params.label,
		x = 0,
		y = 0,
		font = layout.font.heading,
		fontSize = params.fontSize or buttonSettings.fontSize,
	})
	ui.setColor( label, palette.text )

	-- Focus keeps the release coming back to this button, so the active fill always clears.
	local function onTouch( event )
		local phase = event.phase

		if phase == "began" then
			display.getCurrentStage():setFocus( button )
			ui.setColor( background, palette.buttonActiveFill )
			params.onPress()

		elseif phase == "ended" or phase == "cancelled" then
			display.getCurrentStage():setFocus( nil )
			ui.setColor( background, palette.buttonFill )
		end

		return true
	end

	button:addEventListener( "touch", onTouch )

	return button
end

return ui
