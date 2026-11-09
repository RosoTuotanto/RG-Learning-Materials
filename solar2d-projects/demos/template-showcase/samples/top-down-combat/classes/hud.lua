-- Screen-fixed HP bar, wave label, defeat message and hint line, kept outside the group the camera moves.

local hud = {}

--------------------------------------------------------------------------------------
-- Private functions

-- Fits a background to the centre-anchored text's actual size, plus padding on every side.
local function fitBackground( background, text, padding )
	background.x, background.y = text.x, text.y
	background.width = text.width + padding * 2
	background.height = text.height + padding * 2
end

--------------------------------------------------------------------------------------
-- Public functions

-- settings is the whole data/settings.lua table.
function hud.new( parent, settings )
	local style = settings.hud
	local colors = settings.colors

	local overlay = display.newGroup()
	parent:insert( overlay )

	local bar = display.newGroup()
	overlay:insert( bar )

	local barBack = display.newRect( bar, 0, 0, style.barWidth, style.barHeight )
	barBack:setFillColor( unpack( colors.barBack ) )

	local barFill = display.newRect( bar, -style.barWidth * 0.5, 0, style.barWidth, style.barHeight )
	barFill.anchorX = 0
	barFill:setFillColor( unpack( colors.barFill ) )

	local waveLabel = display.newText({
		parent = bar,
		text = "",
		x = 0,
		y = style.barHeight * 0.5 + style.labelGap,
		font = settings.font.heading,
		fontSize = style.labelSize,
	})
	waveLabel.anchorY = 0
	waveLabel:setFillColor( unpack( colors.text ) )

	local message = display.newGroup()
	overlay:insert( message )

	local messageText = display.newText({
		parent = message,
		text = settings.text.defeated,
		font = settings.font.heading,
		fontSize = style.messageSize,
	})
	messageText:setFillColor( unpack( colors.text ) )

	local padding = style.messagePadding
	local messageBack = display.newRect( message, 0, 0, messageText.width + padding * 2, messageText.height + padding )
	messageBack:setFillColor( unpack( colors.messageBack ) )
	messageBack:toBack()

	local hintBackground = display.newRect( overlay, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hint = display.newText({
		parent = overlay,
		text = settings.text.hint,
		font = settings.font.body,
		fontSize = style.hintSize,
	})
	hint:setFillColor( unpack( colors.text ) )

	-- An empty bar hides its fill rather than giving it a zero width.
	function overlay:setHp( hp, maxHp )
		barFill.isVisible = hp > 0

		if hp > 0 then
			barFill.width = style.barWidth * hp / maxHp
		end
	end

	function overlay:setWave( number )
		waveLabel.text = settings.text.wave .. number
	end

	function overlay:showMessage( isVisible )
		message.isVisible = isVisible
	end

	-- The bar and the wave label under it sit top-centre, clear of the back button and the volume slider in the top corners.
	function overlay:position()
		bar.x = display.contentCenterX
		bar.y = display.screenOriginY + style.top

		message.x, message.y = display.contentCenterX, display.contentCenterY

		hint.x = display.contentCenterX
		hint.y = display.screenOriginY + display.actualContentHeight - style.hintBottom
		fitBackground( hintBackground, hint, style.hintPadding )
	end

	overlay:showMessage( false )
	overlay:position()

	return overlay
end

return hud
