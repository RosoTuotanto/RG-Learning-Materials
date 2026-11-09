local hud = {}

--------------------------------------------------------------------------------------
-- Private functions

-- Fits a background around the centre-anchored lines' actual size, plus padding on every side.
local function fitBackground( background, lines, padding )
	local left, top = math.huge, math.huge
	local right, bottom = -math.huge, -math.huge

	for i = 1, #lines do
		local line = lines[i]
		local halfWidth, halfHeight = line.width * 0.5, line.height * 0.5

		left, right = math.min( left, line.x - halfWidth ), math.max( right, line.x + halfWidth )
		top, bottom = math.min( top, line.y - halfHeight ), math.max( bottom, line.y + halfHeight )
	end

	background.x, background.y = ( left + right ) * 0.5, ( top + bottom ) * 0.5
	background.width = right - left + padding * 2
	background.height = bottom - top + padding * 2
end

--------------------------------------------------------------------------------------
-- Public functions

function hud.new( parent, settings )
	local config = settings.hud
	local colors = settings.colors

	local view = display.newGroup()
	parent:insert( view )

	-- The goal line sits one line above the controls line, both centred at the bottom of the screen.
	local hint = display.newGroup()
	view:insert( hint )
	hint.x = display.contentCenterX

	local hintBackground = display.newRect( hint, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local controlsLine = display.newText( hint, settings.text.hint, 0, 0, settings.font.body, config.hintSize )
	controlsLine:setFillColor( unpack( colors.hintText ) )

	local goalLine = display.newText( hint, settings.text.goal, 0, -config.hintLineGap, settings.font.heading, config.hintSize )
	goalLine:setFillColor( unpack( colors.hintText ) )

	-- The background sits in the hint's group, so it follows the hint on resize.
	fitBackground( hintBackground, { controlsLine, goalLine }, config.hintPadding )

	local message = display.newText({
		parent = view,
		text = settings.text.complete,
		x = display.contentCenterX,
		y = display.contentCenterY,
		font = settings.font.heading,
		fontSize = config.messageSize,
	})
	message:setFillColor( unpack( colors.text ) )
	message.isVisible = false

	function view:showHint( isShown )
		hint.isVisible = isShown
	end

	function view:showMessage( isShown )
		message.isVisible = isShown
	end

	-- Call on resize: the hint follows the actual bottom edge.
	function view:position()
		hint.y = display.screenOriginY + display.actualContentHeight - config.hintOffset
	end

	view:position()

	return view
end

return hud
