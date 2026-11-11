-- The heading, caption and buttons are drawn inside the game canvas, because the demo
-- is embedded in a lesson and has to work on its own.

local ui = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )
local strings = require( "data.strings" )
local outfits = require( "data.outfits" )
local screen = require( "scripts.screen" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local uiSettings = layout.ui
local panelSettings = layout.animationPanel
local outfitSettings = layout.outfitPanel

local outfitButtonsHeight = #outfits.slots * outfitSettings.buttonHeight + ( #outfits.slots - 1 ) * outfitSettings.buttonGap
local outfitPanelWidth = outfitSettings.buttonWidth + outfitSettings.paddingX * 2
local outfitPanelHeight = outfitSettings.buttonsOffset - outfitSettings.buttonHeight * 0.5 + outfitButtonsHeight + outfitSettings.paddingBottom

local group
local headingText
local captionText

local styleButton
local panelGroup
local buttons = {}

local outfitGroup
local outfitButtons = {}

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

-- Keeps the row on the bottom of the visible screen.
local function placeRow()
	local rowHeight = math.max( uiSettings.styleButtonHeight, panelSettings.height )
	local rowY = screen.maxY - uiSettings.bottomMargin - rowHeight * 0.5

	styleButton.y = rowY
	panelGroup.y = rowY
end

-- Keeps the outfit panel on the right edge of the visible screen, at a fixed height over the floor.
local function placeOutfitPanel()
	local floorTop = layout.floor.y - layout.floor.height * 0.5

	outfitGroup.x = screen.maxX - outfitSettings.rightMargin - outfitPanelWidth * 0.5
	outfitGroup.y = floorTop - outfitSettings.floorOffset - outfitPanelHeight * 0.5
end

-- The visible screen moves when an HTML5 window resizes. Refreshing screen first keeps this
-- independent of the order Runtime runs resize listeners in.
local function placeControls()
	screen.update()
	placeRow()
	placeOutfitPanel()
end

-- The panel holds the title and the animation buttons, with positions relative to the panel centre.
local function newAnimationPanel( params )
	local names = params.names
	local panelWidth = #names * uiSettings.buttonWidth + ( #names - 1 ) * uiSettings.buttonGap + panelSettings.paddingX * 2

	local panel = display.newGroup()
	params.parent:insert( panel )

	local background = display.newRoundedRect( panel, 0, 0, panelWidth, panelSettings.height, panelSettings.cornerRadius )
	setColor( background, palette.panelFill )
	background.strokeWidth = 2
	background:setStrokeColor( palette.panelBorder[1], palette.panelBorder[2], palette.panelBorder[3] )

	local top = -panelSettings.height * 0.5

	local title = display.newText({
		parent = panel,
		text = strings.animationPanelTitle,
		x = 0,
		y = top + panelSettings.titleOffset,
		font = layout.font.heading,
		fontSize = panelSettings.titleSize,
	})
	setColor( title, palette.textMuted )

	local x = -panelWidth * 0.5 + panelSettings.paddingX + uiSettings.buttonWidth * 0.5

	for i = 1, #names do
		local name = names[i]

		buttons[i] = newButton({
			parent = panel,
			id = name,
			x = x,
			y = top + panelSettings.buttonsOffset,
			width = uiSettings.buttonWidth,
			height = uiSettings.buttonHeight,
			label = strings.buttonLabel[name],
			fontSize = uiSettings.fontSize,
			onPress = function()
				params.onSelect( name )
			end,
		})

		x = x + uiSettings.buttonWidth + uiSettings.buttonGap
	end

	return panel, panelWidth
end

-- The panel holds the title and the outfit buttons top to bottom, with positions relative to the panel centre.
local function newOutfitPanel( params )
	local panel = display.newGroup()
	params.parent:insert( panel )

	local background = display.newRoundedRect( panel, 0, 0, outfitPanelWidth, outfitPanelHeight, panelSettings.cornerRadius )
	setColor( background, palette.panelFill )
	background.strokeWidth = 2
	background:setStrokeColor( palette.panelBorder[1], palette.panelBorder[2], palette.panelBorder[3] )

	local top = -outfitPanelHeight * 0.5

	local title = display.newText({
		parent = panel,
		text = strings.outfitPanelTitle,
		x = 0,
		y = top + panelSettings.titleOffset,
		font = layout.font.heading,
		fontSize = panelSettings.titleSize,
	})
	setColor( title, palette.textMuted )

	local y = top + outfitSettings.buttonsOffset

	for i = 1, #outfits.slots do
		local slot = outfits.slots[i]

		outfitButtons[i] = newButton({
			parent = panel,
			id = slot,
			x = 0,
			y = y,
			width = outfitSettings.buttonWidth,
			height = outfitSettings.buttonHeight,
			label = strings.outfitButtonLabel[slot][outfits.options[slot][1]],
			fontSize = outfitSettings.fontSize,
			onPress = function()
				params.onToggle( slot )
			end,
		})

		y = y + outfitSettings.buttonHeight + outfitSettings.buttonGap
	end

	return panel
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, names (the animation names in button order), onSelect( name ), onStyleChange,
-- onOutfitToggle( slot )
function ui.create( params )
	local panelWidth

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

	-- The style button leads the row, followed by the animation panel. The panel is built
	-- first because its width decides where the row's left edge sits.
	panelGroup, panelWidth = newAnimationPanel({
		parent = group,
		names = params.names,
		onSelect = params.onSelect,
	})

	local positions = layoutRow(
		{ uiSettings.styleButtonWidth, panelWidth },
		{ uiSettings.styleButtonGap }
	)

	panelGroup.x = positions[2]

	styleButton = newButton({
		parent = group,
		id = "style",
		x = positions[1],
		y = 0,
		width = uiSettings.styleButtonWidth,
		height = uiSettings.styleButtonHeight,
		label = strings.styleButtonLabel,
		fontSize = uiSettings.styleButtonFontSize,
		onPress = params.onStyleChange,
	})

	outfitGroup = newOutfitPanel({
		parent = group,
		onToggle = params.onOutfitToggle,
	})

	placeControls()
	Runtime:addEventListener( "resize", placeControls )
end

-- Re-reads everything shown from the demo state: the texts, the outfit labels and the highlighted buttons.
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

	-- A hidden group takes no touches, so the outfit buttons only work on the skeletal view.
	outfitGroup.isVisible = state:isSkeletal()

	for i = 1, #outfitButtons do
		local button = outfitButtons[i]
		local slot = button.id

		button.label.text = strings.outfitButtonLabel[slot][state:getOutfitOption( slot )]
		button:setActive( outfits.highlighted[slot] == true and state:isOutfitChanged( slot ) )
	end
end

function ui.destroy()
	Runtime:removeEventListener( "resize", placeControls )
	display.remove( group )

	group = nil
	headingText = nil
	captionText = nil
	buttons = {}
	outfitButtons = {}
end

--------------------------------------------------------------------------------------

return ui
