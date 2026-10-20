-- Every control in the demo: the seven version buttons, the volume slider, the reset
-- button and the language toggle. All of it is drawn inside the game canvas rather than
-- in the surrounding page, because the demo is embedded in a lesson and has to work on
-- its own. Controls are plain display objects with touch listeners, not widget objects.

local ui = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )
local versions = require( "data.versions" )
local language = require( "scripts.language" )
local screen = require( "scripts.screen" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local uiSettings = layout.ui
local sliderSettings = layout.ui.slider
local cornerSettings = layout.ui.corner

local callbacks = {}

local group
local titleText
local captionText
local soundLabel
local soundHint
local soundValue
local slider

local versionButtons = {}
local flags = {}
local currentVersion = 1

--------------------------------------------------------------------------------------
-- Localised functions

local mathSin = math.sin
local mathCos = math.cos
local mathRad = math.rad
local mathMin = math.min
local mathMax = math.max

--------------------------------------------------------------------------------------
-- Private functions

local function setColor( object, color )
	object:setFillColor( color[1], color[2], color[3] )
end

-- newPolygon re-centres a vertex list on its own bounding box rather than treating the
-- values as offsets from the position it is given, so the list is handed over relative
-- to that centre and the shape is then placed at it.
local function newCenteredPolygon( parent, vertices )
	local minX, maxX = vertices[1], vertices[1]
	local minY, maxY = vertices[2], vertices[2]

	for i = 3, #vertices, 2 do
		minX = mathMin( minX, vertices[i] )
		maxX = mathMax( maxX, vertices[i] )
		minY = mathMin( minY, vertices[i + 1] )
		maxY = mathMax( maxY, vertices[i + 1] )
	end

	local centerX = ( minX + maxX ) * 0.5
	local centerY = ( minY + maxY ) * 0.5

	local relative = {}

	for i = 1, #vertices, 2 do
		relative[i] = vertices[i] - centerX
		relative[i + 1] = vertices[i + 1] - centerY
	end

	return display.newPolygon( parent, centerX, centerY, relative )
end

-- The restart arrow, drawn rather than typed. The project's Roboto files carry no
-- circular-arrow glyph, and a glyph a font does not have is a blank box at runtime.
local function newRestartIcon( parent )
	local radius = cornerSettings.iconRadius
	local sweep = cornerSettings.iconSweep
	local segments = 24

	-- The arc stops at one edge of the opening and the head is placed there, so the tail
	-- and the head frame the gap between them.
	local endAngle = cornerSettings.iconGapAngle - ( 360 - sweep ) * 0.5
	local startAngle = endAngle - sweep

	-- y grows downwards, so sweeping the angle upwards travels clockwise on screen.
	local function pointAt( index )
		local angle = mathRad( startAngle + sweep * index / segments )

		return mathCos( angle ) * radius, mathSin( angle ) * radius
	end

	local firstX, firstY = pointAt( 0 )
	local secondX, secondY = pointAt( 1 )

	local arc = display.newLine( parent, firstX, firstY, secondX, secondY )

	for i = 2, segments do
		arc:append( pointAt( i ) )
	end

	arc.strokeWidth = cornerSettings.iconStroke
	arc:setStrokeColor( palette.text[1], palette.text[2], palette.text[3] )

	-- The head points along the direction of travel and straddles the stroke radially.
	local tipAngle = mathRad( endAngle )
	local endX, endY = mathCos( tipAngle ) * radius, mathSin( tipAngle ) * radius
	local alongX, alongY = -mathSin( tipAngle ), mathCos( tipAngle )
	local outX, outY = mathCos( tipAngle ), mathSin( tipAngle )
	local reach = cornerSettings.iconHead * 0.5

	local head = newCenteredPolygon( parent, {
		endX + alongX * reach, endY + alongY * reach,
		endX - outX * reach, endY - outY * reach,
		endX + outX * reach, endY + outY * reach,
	})
	setColor( head, palette.text )
end

-- One flag per language, all created up front and swapped by visibility. The plate
-- behind them gives the Finnish white and the Union blue an edge against the dark fill.
local function newFlag( parent, code )
	local instance = display.newGroup()
	parent:insert( instance )

	local width = cornerSettings.flagWidth
	local height = width * cornerSettings.flagRatio[code]
	local border = cornerSettings.flagBorder

	local plate = display.newRect( instance, 0, 0, width + border * 2, height + border * 2 )
	setColor( plate, palette.buttonBorder )

	display.newImageRect( instance, "assets/images/flag_" .. code .. ".png", width, height )

	return instance
end

-- params: parent, x, y, width, height, onPress, plus an optional label and fontSize for
-- a text button and an optional id for one that carries an icon instead.
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

	if params.label then
		button.label = display.newText({
			parent = button,
			text = params.label,
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

	-- The listener sits on the group. A hit on the background or on anything drawn over
	-- it is dispatched to the deepest object first and then to its ancestors, so the
	-- group receives it wherever inside the button the press lands.
	button:addEventListener( "touch", function( event )
		if event.phase == "began" then
			params.onPress()
		end

		return true
	end )

	return button
end

-- A slider rather than an on/off button, because "how loud" is the question a lesson
-- page visitor actually has. params: parent, x, y, onChange
local function newSlider( params )
	local instance = display.newGroup()
	instance.x = params.x
	instance.y = params.y
	params.parent:insert( instance )

	local width = sliderSettings.width
	local halfWidth = width * 0.5

	local track = display.newRoundedRect( instance, 0, 0, width, sliderSettings.trackHeight, sliderSettings.trackHeight * 0.5 )
	setColor( track, palette.sliderTrack )

	-- Scaled rather than resized: assigning to width would multiply the object's scale
	-- instead of setting its size.
	local fill = display.newRect( instance, -halfWidth, 0, width, sliderSettings.trackHeight )
	fill.anchorX = 0
	setColor( fill, palette.sliderFill )

	local knob = display.newRoundedRect( instance, 0, 0, sliderSettings.knobWidth, sliderSettings.knobHeight, 4 )
	setColor( knob, palette.sliderKnob )

	instance.value = 0

	function instance:setValue( value )
		self.value = mathMax( 0, mathMin( 1, value ) )

		fill.xScale = mathMax( self.value, 0.0001 )
		fill.isVisible = self.value > 0
		knob.x = -halfWidth + self.value * width
	end

	-- The UI group never moves, so an event's content x can be compared against the
	-- track's own position directly.
	local function valueFromTouch( event )
		return ( event.x - ( params.x - halfWidth ) ) / width
	end

	instance:addEventListener( "touch", function( event )
		local phase = event.phase

		if phase == "began" then
			display.getCurrentStage():setFocus( instance )
			instance.isDragging = true
			instance:setValue( valueFromTouch( event ) )
			params.onChange( instance.value )

		elseif instance.isDragging then
			if phase == "moved" then
				instance:setValue( valueFromTouch( event ) )
				params.onChange( instance.value )

			else
				display.getCurrentStage():setFocus( nil )
				instance.isDragging = false
			end
		end

		return true
	end )

	return instance
end

-- Lays a row of buttons out left to right and centres the row as a whole.
local function layoutRow( widths, gap )
	local totalWidth = 0

	for i = 1, #widths do
		totalWidth = totalWidth + widths[i]
	end

	totalWidth = totalWidth + gap * ( #widths - 1 )

	local positions = {}
	local currentX = screen.centerX - totalWidth * 0.5

	for i = 1, #widths do
		positions[i] = currentX + widths[i] * 0.5
		currentX = currentX + widths[i] + gap
	end

	return positions
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, callbacks with onVersion, onVolume, onLanguage and onReset
function ui.create( params )
	callbacks = params.callbacks

	group = display.newGroup()
	params.parent:insert( group )

	titleText = display.newText({
		parent = group,
		text = "",
		x = screen.centerX,
		y = layout.caption.titleY,
		font = layout.font.heading,
		fontSize = layout.caption.titleSize,
	})
	setColor( titleText, palette.text )

	captionText = display.newText({
		parent = group,
		text = "",
		x = screen.centerX,
		y = layout.caption.textY,
		width = layout.caption.width,
		font = layout.font.body,
		fontSize = layout.caption.textSize,
		align = "center",
	})
	-- Anchored to its top, so a caption that wraps to two lines starts at the same
	-- height as one that fits on a single line.
	captionText.anchorY = 0
	setColor( captionText, palette.textMuted )

	local cornerY = screen.minY + cornerSettings.marginY + cornerSettings.size * 0.5

	local resetButton = newButton({
		parent = group,
		id = "reset",
		x = screen.minX + cornerSettings.marginX + cornerSettings.size * 0.5,
		y = cornerY,
		width = cornerSettings.size,
		height = cornerSettings.size,
		onPress = function()
			callbacks.onReset()
		end,
	})

	newRestartIcon( resetButton )

	local languageButton = newButton({
		parent = group,
		id = "language",
		x = screen.maxX - cornerSettings.marginX - cornerSettings.size * 0.5,
		y = cornerY,
		width = cornerSettings.size,
		height = cornerSettings.size,
		onPress = function()
			callbacks.onLanguage()
		end,
	})

	for code in pairs( cornerSettings.flagRatio ) do
		flags[code] = newFlag( languageButton, code )
	end

	local versionRowY = screen.maxY - uiSettings.bottomMargin - uiSettings.buttonHeight * 0.5
	local sliderRowY = versionRowY - uiSettings.rowGap

	local versionWidths = {}

	for i = 1, #versions.adds do
		versionWidths[i] = uiSettings.versionWidth
	end

	local versionPositions = layoutRow( versionWidths, uiSettings.buttonGap )

	for i = 1, #versions.adds do
		versionButtons[i] = newButton({
			parent = group,
			x = versionPositions[i],
			y = versionRowY,
			width = uiSettings.versionWidth,
			height = uiSettings.buttonHeight,
			label = tostring( i ),
			fontSize = uiSettings.versionSize,
			onPress = function()
				callbacks.onVersion( i )
			end,
		})
	end

	slider = newSlider({
		parent = group,
		x = screen.centerX,
		y = sliderRowY,
		onChange = function( value )
			ui.setVolumeLabel( value )
			callbacks.onVolume( value )
		end,
	})

	soundLabel = display.newText({
		parent = group,
		text = "",
		x = screen.centerX - sliderSettings.width * 0.5 - sliderSettings.labelGap,
		y = sliderRowY,
		font = layout.font.heading,
		fontSize = sliderSettings.labelSize,
	})
	soundLabel.anchorX = 1
	setColor( soundLabel, palette.text )

	soundValue = display.newText({
		parent = group,
		text = "",
		x = screen.centerX + sliderSettings.width * 0.5 + sliderSettings.valueGap,
		y = sliderRowY,
		font = layout.font.body,
		fontSize = sliderSettings.labelSize,
	})
	soundValue.anchorX = 0
	setColor( soundValue, palette.text )

	soundHint = display.newText({
		parent = group,
		text = "",
		x = screen.centerX,
		y = sliderRowY + sliderSettings.hintOffsetY,
		font = layout.font.body,
		fontSize = sliderSettings.hintSize,
	})
	setColor( soundHint, palette.textMuted )
end

function ui.setVersion( index )
	currentVersion = index

	for i = 1, #versionButtons do
		versionButtons[i]:setActive( i == index )
	end

	ui.refreshText()
end

function ui.setVolume( value )
	slider:setValue( value )
	ui.setVolumeLabel( value )
end

function ui.setVolumeLabel( value )
	soundValue.text = string.format( language.strings().percentFormat, math.floor( value * 100 + 0.5 ) )
end

-- Re-reads every string from the language in use. Called on creation and on every
-- language switch, so there is only one place that knows which text goes where.
function ui.refreshText()
	local strings = language.strings()
	local code = language.get()

	titleText.text = strings.versionTitle[currentVersion]
	captionText.text = strings.versionCaption[currentVersion]
	soundLabel.text = strings.soundLabel
	soundHint.text = strings.soundHint

	-- The button carries the flag of the language showing, not of the one it switches to.
	for flagCode, flag in pairs( flags ) do
		flag.isVisible = flagCode == code
	end

	ui.setVolumeLabel( slider.value )
end

function ui.destroy()
	display.remove( group )

	group = nil
	titleText = nil
	captionText = nil
	soundLabel = nil
	soundHint = nil
	soundValue = nil
	slider = nil
	versionButtons = {}
	flags = {}
end

--------------------------------------------------------------------------------------

return ui
