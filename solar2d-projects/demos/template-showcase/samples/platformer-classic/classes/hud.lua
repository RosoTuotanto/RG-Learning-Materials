local hud = {}

--------------------------------------------------------------------------------------
-- Private functions

-- Fits a background to the text's actual size, plus padding on every side.
local function fitBackground( background, text, padding )
	background.x, background.y = text.x, text.y
	background.width = text.width + padding * 2
	background.height = text.height + padding * 2
end

--------------------------------------------------------------------------------------
-- Public functions

function hud.new( parent, sheet, settings )
	local config = settings.hud
	local colors = settings.colors
	local heartCount = settings.player.hearts
	local iconSize = settings.sheets.tiles.displaySize

	local view = display.newGroup()
	parent:insert( view )

	-- Hearts sit left of the screen centre and the coin count right of it, clear of both top corners.
	local top = display.newGroup()
	top.x = display.contentCenterX
	view:insert( top )

	local hearts = {}
	for i = 1, heartCount do
		hearts[i] = display.newSprite( top, sheet, config.heartSequence )
		hearts[i].x = -config.gap * 0.5 - ( heartCount - i + 0.5 ) * config.heartSpacing
	end

	local coinIcon = display.newSprite( top, sheet, settings.coin.sequence )
	coinIcon.x = config.gap * 0.5 + iconSize * 0.5

	local coinLabel = display.newText({
		parent = top,
		text = "",
		x = coinIcon.x + iconSize * 0.5 + config.coinLabelGap,
		y = 0,
		font = settings.font.heading,
		fontSize = config.coinLabelSize,
	})
	coinLabel.anchorX = 0
	coinLabel:setFillColor( unpack( colors.text ) )

	local hintBackground = display.newRect( view, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hint = display.newText({
		parent = view,
		text = settings.text.hint,
		x = display.contentCenterX,
		y = 0,
		font = settings.font.body,
		fontSize = config.hintSize,
	})
	hint:setFillColor( unpack( colors.hintText ) )

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

	function view:setHearts( count )
		for i = 1, #hearts do
			hearts[i]:setFrame( i <= count and 1 or 2 )
		end
	end

	function view:setCoins( count )
		coinLabel.text = tostring( count )
	end

	function view:showMessage( isShown )
		message.isVisible = isShown
	end

	-- Call on resize: the top row and the hint follow the actual screen edges.
	function view:position()
		top.y = display.screenOriginY + config.topOffset
		hint.y = display.screenOriginY + display.actualContentHeight - config.hintOffset
		fitBackground( hintBackground, hint, config.hintPadding )
	end

	view:position()

	return view
end

return hud
