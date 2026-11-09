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
	local text = settings.text

	local view = display.newGroup()
	parent:insert( view )

	local function newLabel( group, size, font )
		local label = display.newText({ parent = group, text = "", x = 0, y = 0, font = font, fontSize = size })
		label:setFillColor( unpack( colors.text ) )

		return label
	end

	-- The health panel's origin is its centre, and its label and bar sit side by side centred on it.
	local hpPanel = display.newGroup()
	view:insert( hpPanel )

	local hpBackground = display.newRect( hpPanel, 0, 0, 1, 1 )
	hpBackground:setFillColor( unpack( colors.hpPanel ) )

	local hpLabel = newLabel( hpPanel, config.labelSize, settings.font.heading )
	hpLabel.anchorX = 0
	hpLabel.text = text.hp
	hpLabel:setFillColor( unpack( colors.hpText ) )

	local contentWidth = hpLabel.width + config.labelGap + config.barWidth
	hpLabel.x = -contentWidth * 0.5

	local barBack = display.newRect( hpPanel, hpLabel.x + hpLabel.width + config.labelGap, 0, config.barWidth, config.barHeight )
	barBack.anchorX = 0
	barBack:setFillColor( unpack( colors.hpBack ) )

	local barFill = display.newRect( hpPanel, barBack.x, 0, config.barWidth, config.barHeight )
	barFill.anchorX = 0
	barFill:setFillColor( unpack( colors.hpFill ) )

	hpBackground.width = contentWidth + config.hpPadding * 2
	hpBackground.height = math.max( hpLabel.height, config.barHeight ) + config.hpPadding * 2

	local hintBackground = display.newRect( view, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hints = {}
	for i = 1, #text.hint do
		hints[i] = newLabel( view, config.hintSize, settings.font.body )
		hints[i].text = text.hint[i]
		hints[i]:setFillColor( unpack( colors.hintText ) )
	end

	local message = newLabel( view, config.messageSize, settings.font.heading )
	message.x, message.y = display.contentCenterX, display.contentCenterY
	message.isVisible = false

	function view:setHp( hp, maxHp )
		barFill.isVisible = hp > 0

		if hp > 0 then
			barFill.xScale = hp / maxHp
		end
	end

	-- Pass nil to hide the message.
	function view:showMessage( messageText )
		message.text = messageText or ""
		message.isVisible = messageText ~= nil
	end

	-- Call on resize: the health panel and the hints follow the actual screen edges.
	function view:position()
		local bottom = display.screenOriginY + display.actualContentHeight

		hpPanel.x = display.screenOriginX + display.actualContentWidth * 0.5
		hpPanel.y = display.screenOriginY + config.hpTop + hpBackground.height * 0.5

		for i = 1, #hints do
			hints[i].x, hints[i].y = display.contentCenterX, bottom - config.hintOffsets[i]
		end

		fitBackground( hintBackground, hints, config.hintPadding )
	end

	view:position()

	return view
end

return hud
