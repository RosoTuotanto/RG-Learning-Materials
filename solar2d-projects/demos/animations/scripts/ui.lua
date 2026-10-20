-- The heading, caption, description and buttons are drawn inside the game canvas, because the demo
-- is embedded in a lesson and has to work on its own.

local ui = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )
local strings = require( "data.strings" )
local screen = require( "scripts.screen" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local uiSettings = layout.ui

local group
local headingText
local captionText
local descriptionText

local buttons = {}
local rowButtons = {}

--------------------------------------------------------------------------------------
-- Private functions

local function setColor( object, color )
	object:setFillColor( color[1], color[2], color[3] )
end

-- params: parent, x, y, width, height, label, fontSize, id, onPress
local function newButton( params )
	local button = display.newGroup()
	button.x = params.x
	button.y = params.y
	button.id = params.id
	params.parent:insert( button )

	button.background = display.newRoundedRect( button, 0, 0, params.width, params.height, uiSettings.cornerRadius )
	setColor( button.background, palette.buttonFill )
	button.background.strokeWidth = 2
	button.background:setStrokeColor( palette.buttonBorder[1], palette.buttonBorder[2], palette.buttonBorder[3] )

	button.label = display.newText({
		parent = button,
		text = params.label,
		x = 0,
		y = 0,
		font = layout.font.heading,
		fontSize = params.fontSize,
	})
	setColor( button.label, palette.text )

	function button:setActive( isActive )
		setColor( self.background, isActive and palette.buttonActiveFill or palette.buttonFill )
	end

	button:addEventListener( "touch", function( event )
		if event.phase == "began" then
			params.onPress()
		end

		return true
	end )

	return button
end

-- Lays buttons out left to right, gaps[i] after button i, and centres the row as a whole.
local function layoutRow( widths, gaps )
	local totalWidth = 0

	for i = 1, #widths do
		totalWidth = totalWidth + widths[i]
	end

	for i = 1, #widths - 1 do
		totalWidth = totalWidth + gaps[i]
	end

	local positions = {}
	local left = screen.centerX - totalWidth * 0.5

	for i = 1, #widths do
		positions[i] = left + widths[i] * 0.5
		left = left + widths[i] + ( gaps[i] or 0 )
	end

	return positions
end

-- Keeps the row on the bottom of the visible screen, which moves when an HTML5 window resizes.
-- Refreshing screen first keeps this independent of the order Runtime runs resize listeners in.
local function placeRow()
	screen.update()

	local rowHeight = math.max( uiSettings.styleButtonHeight, uiSettings.buttonHeight )
	local rowY = screen.maxY - uiSettings.bottomMargin - rowHeight * 0.5

	for i = 1, #rowButtons do
		rowButtons[i].y = rowY
	end
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, names (the animation names in button order), onSelect( name ), onStyleChange
function ui.create( params )
	group = display.newGroup()
	params.parent:insert( group )

	headingText = display.newText({
		parent = group,
		text = "",
		x = screen.centerX,
		y = layout.heading.y,
		font = layout.font.heading,
		fontSize = layout.heading.size,
	})
	setColor( headingText, palette.text )

	captionText = display.newText({
		parent = group,
		text = "",
		x = screen.centerX,
		y = layout.caption.y,
		font = layout.font.body,
		fontSize = layout.caption.size,
	})
	setColor( captionText, palette.textMuted )

	descriptionText = display.newText({
		parent = group,
		text = "",
		x = screen.centerX,
		y = layout.description.y,
		width = layout.description.width,
		font = layout.font.body,
		fontSize = layout.description.size,
		align = "center",
	})
	setColor( descriptionText, palette.textMuted )

	-- The style button leads the row, followed by the animation buttons.
	local names = params.names
	local widths = { uiSettings.styleButtonWidth }
	local gaps = { uiSettings.styleButtonGap }

	for i = 1, #names do
		widths[i + 1] = uiSettings.buttonWidth
		gaps[i + 1] = uiSettings.buttonGap
	end

	local positions = layoutRow( widths, gaps )

	rowButtons[1] = newButton({
		parent = group,
		id = "style",
		x = positions[1],
		y = 0,
		width = uiSettings.styleButtonWidth,
		height = uiSettings.styleButtonHeight,
		label = strings.styleButtonLabel,
		fontSize = uiSettings.fontSize,
		onPress = params.onStyleChange,
	})

	for i = 1, #names do
		local name = names[i]

		buttons[i] = newButton({
			parent = group,
			id = name,
			x = positions[i + 1],
			y = 0,
			width = uiSettings.buttonWidth,
			height = uiSettings.buttonHeight,
			label = strings.buttonLabel[name],
			fontSize = uiSettings.fontSize,
			onPress = function()
				params.onSelect( name )
			end,
		})

		rowButtons[i + 1] = buttons[i]
	end

	placeRow()
	Runtime:addEventListener( "resize", placeRow )
end

-- Re-reads everything shown from the demo state: the texts and the highlighted button.
function ui.refresh( state )
	local style = state:getStyle()
	local animation = state:getAnimation()

	for i = 1, #buttons do
		buttons[i]:setActive( buttons[i].id == animation )
	end

	local caption = string.format( strings.captionFormat, animation )

	if state:isSkeletal() then
		caption = string.format( strings.skeletalCaptionFormat, caption, state:getVariant(), state:getVariantCount() )
	end

	headingText.text = strings.heading[style]
	captionText.text = caption
	descriptionText.text = strings.description[style]
end

function ui.destroy()
	Runtime:removeEventListener( "resize", placeRow )
	display.remove( group )

	group = nil
	headingText = nil
	captionText = nil
	descriptionText = nil
	buttons = {}
	rowButtons = {}
end

--------------------------------------------------------------------------------------

return ui
