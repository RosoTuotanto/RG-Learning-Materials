-- The lesson's pressable circle as version 1 and version 9, switched with two buttons.

display.setStatusBar( display.HiddenStatusBar )

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )
local language = require( "scripts.language" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local uiSettings = layout.ui
local cornerSettings = layout.ui.corner

-- Same order as versionName and versionCaption in data/strings.lua.
local versionModules = { "scripts.version1", "scripts.version9" }

-- The circle and every control share the content rect, which letterbox never crops.
local contentCenterX = display.contentCenterX
local contentWidth = display.contentWidth
local contentHeight = display.contentHeight

local uiGroup
local titleText
local captionText
local instructionText
local versionButtons = {}
local flags = {}
local currentVersion
local currentCircle

--------------------------------------------------------------------------------------
-- Functions

local function setColor( object, color )
	object:setFillColor( color[1], color[2], color[3] )
end

-- One flag per language, swapped by visibility. The plate gives both flags an edge against the dark fill.
local function newFlag( parent, code )
	local flag = display.newGroup()
	parent:insert( flag )

	local width = cornerSettings.flagWidth
	local height = width * cornerSettings.flagRatio[code]
	local border = cornerSettings.flagBorder

	local plate = display.newRect( flag, 0, 0, width + border * 2, height + border * 2 )
	setColor( plate, palette.buttonBorder )

	display.newImageRect( flag, "assets/images/flag_" .. code .. ".png", width, height )

	return flag
end

-- params: x, y, width, height, onPress, plus an optional fontSize for a button that carries a label.
local function newButton( params )
	local button = display.newGroup()
	button.x = params.x
	button.y = params.y
	uiGroup:insert( button )

	button.background = display.newRoundedRect( button, 0, 0, params.width, params.height, uiSettings.cornerRadius )
	setColor( button.background, palette.buttonFill )
	button.background.strokeWidth = uiSettings.strokeWidth
	button.background:setStrokeColor( palette.buttonBorder[1], palette.buttonBorder[2], palette.buttonBorder[3] )

	if params.fontSize then
		button.label = display.newText({
			parent = button,
			text = "",
			x = 0,
			y = 0,
			font = layout.font.heading,
			fontSize = params.fontSize,
		})
		setColor( button.label, palette.text )
	end

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

local function refreshText()
	local strings = language.strings()
	local code = language.get()

	titleText.text = strings.versionName[currentVersion]
	captionText.text = strings.versionCaption[currentVersion]
	instructionText.text = strings.instruction

	for i = 1, #versionButtons do
		versionButtons[i].label.text = strings.versionName[i]
	end

	-- The button carries the flag of the language showing, not of the one it switches to.
	for flagCode, flag in pairs( flags ) do
		flag.isVisible = flagCode == code
	end
end

-- Selecting the version already showing restarts it, which also undoes version 1's stuck-big bug.
local function selectVersion( index )
	if currentCircle then
		transition.cancel( currentCircle )
		display.remove( currentCircle )
		currentCircle = nil
	end

	-- Version 9 holds focus on its circle for the length of a touch.
	display.getCurrentStage():setFocus( nil )

	-- The version files are the lesson's listings, which build their circle as they load,
	-- so a fresh circle needs the module to run again.
	local moduleName = versionModules[index]
	package.loaded[moduleName] = nil
	currentCircle = require( moduleName )

	-- The circle lands on top of the stage, and version 1's can grow over the buttons.
	uiGroup:toFront()

	currentVersion = index

	for i = 1, #versionButtons do
		versionButtons[i]:setActive( i == index )
	end

	refreshText()
end

--------------------------------------------------------------------------------------
-- Setup

local background = palette.background

-- Set as the default rather than drawn as a rect, so it also covers any letterbox area.
display.setDefault( "background", background[1], background[2], background[3] )

language.init()

uiGroup = display.newGroup()

titleText = display.newText({
	parent = uiGroup,
	text = "",
	x = contentCenterX,
	y = layout.caption.titleY,
	font = layout.font.heading,
	fontSize = layout.caption.titleSize,
})
setColor( titleText, palette.text )

captionText = display.newText({
	parent = uiGroup,
	text = "",
	x = contentCenterX,
	y = layout.caption.textY,
	width = layout.caption.width,
	font = layout.font.body,
	fontSize = layout.caption.textSize,
	align = "center",
})
captionText.anchorY = 0
setColor( captionText, palette.textMuted )

local languageButton = newButton({
	x = contentWidth - cornerSettings.marginX - cornerSettings.size * 0.5,
	y = cornerSettings.marginY + cornerSettings.size * 0.5,
	width = cornerSettings.size,
	height = cornerSettings.size,
	onPress = function()
		language.toggle()
		refreshText()
	end,
})

for code in pairs( cornerSettings.flagRatio ) do
	flags[code] = newFlag( languageButton, code )
end

local buttonY = contentHeight - uiSettings.bottomMargin - uiSettings.buttonHeight * 0.5
local rowWidth = #versionModules * uiSettings.buttonWidth + ( #versionModules - 1 ) * uiSettings.buttonGap
local firstButtonX = contentCenterX - rowWidth * 0.5 + uiSettings.buttonWidth * 0.5

for i = 1, #versionModules do
	versionButtons[i] = newButton({
		x = firstButtonX + ( i - 1 ) * ( uiSettings.buttonWidth + uiSettings.buttonGap ),
		y = buttonY,
		width = uiSettings.buttonWidth,
		height = uiSettings.buttonHeight,
		fontSize = uiSettings.labelSize,
		onPress = function()
			selectVersion( i )
		end,
	})
end

instructionText = display.newText({
	parent = uiGroup,
	text = "",
	x = contentCenterX,
	y = buttonY - uiSettings.buttonHeight * 0.5 - layout.instruction.gap,
	font = layout.font.body,
	fontSize = layout.instruction.size,
})
setColor( instructionText, palette.textMuted )

selectVersion( 1 )
