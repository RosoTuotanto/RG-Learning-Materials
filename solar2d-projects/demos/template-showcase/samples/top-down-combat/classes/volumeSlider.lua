-- A labelled master volume slider on a solid panel in the top-right corner of the actual screen.

local volumeSlider = {}

--------------------------------------------------------------------------------------
-- Localised functions

local max = math.max
local min = math.min

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, font and style (settings.volumeSlider).
function volumeSlider.new( params )
	local style = params.style
	local colors = style.colors

	local width = style.width
	local halfWidth = width * 0.5

	local slider = display.newGroup()
	params.parent:insert( slider )

	-- Sized to the label and track once the label exists, so both read clearly over any art.
	local background = display.newRect( slider, 0, 0, 1, 1 )
	background:setFillColor( unpack( colors.background ) )

	-- The panel swallows touches, so pressing it never reaches the game under it.
	background:addEventListener( "touch", function() return true end )

	local label = display.newText({
		parent = slider,
		text = style.label,
		x = -halfWidth - style.knobWidth * 0.5 - style.labelGap,
		y = 0,
		font = params.font,
		fontSize = style.labelSize,
	})
	label.anchorX = 1
	label:setFillColor( unpack( colors.label ) )

	local panelLeft = label.x - label.width - style.padding
	local panelRight = halfWidth + style.knobWidth * 0.5 + style.padding
	local panelHalfHeight = max( label.height, style.knobHeight ) * 0.5 + style.padding

	background.width = panelRight - panelLeft
	background.height = panelHalfHeight * 2
	background.x = ( panelLeft + panelRight ) * 0.5

	-- Only the track moves the knob.
	local control = display.newGroup()
	slider:insert( control )

	-- An invisible strip as tall as the knob, so the thin track is easy to grab.
	local hitArea = display.newRect( control, 0, 0, width + style.knobWidth, style.knobHeight )
	hitArea.isVisible = false
	hitArea.isHitTestable = true

	local track = display.newRoundedRect( control, 0, 0, width, style.trackHeight, style.trackHeight * 0.5 )
	track:setFillColor( unpack( colors.track ) )

	local fill = display.newRect( control, -halfWidth, 0, width, style.trackHeight )
	fill.anchorX = 0
	fill:setFillColor( unpack( colors.fill ) )

	local knob = display.newRoundedRect( control, 0, 0, style.knobWidth, style.knobHeight, style.knobCornerRadius )
	knob:setFillColor( unpack( colors.knob ) )

	local isDragging = false

	local function setValue( value )
		value = max( 0, min( 1, value ) )

		fill.width = value * width
		knob.x = -halfWidth + value * width

		return value
	end

	local function onTouch( event )
		local phase = event.phase

		if phase == "began" then
			display.getCurrentStage():setFocus( control )
			isDragging = true

		elseif not isDragging then
			return true

		elseif phase == "ended" or phase == "cancelled" then
			display.getCurrentStage():setFocus( nil )
			isDragging = false

			return true
		end

		-- The slider moves on resize, so the touch is read in the control's own coordinates.
		local x = control:contentToLocal( event.x, event.y )
		audio.setVolume( setValue( ( x + halfWidth ) / width ) )

		return true
	end

	control:addEventListener( "touch", onTouch )

	-- The sample calls this from its own resize handler.
	function slider:reposition()
		self.x = display.screenOriginX + display.actualContentWidth - style.margin - panelRight
		self.y = display.screenOriginY + style.margin + panelHalfHeight
	end

	-- Releases a drag still in progress when the scene hides.
	function slider:stop()
		if isDragging then
			display.getCurrentStage():setFocus( nil )
			isDragging = false
		end
	end

	setValue( audio.getVolume() )
	slider:reposition()

	return slider
end

return volumeSlider
