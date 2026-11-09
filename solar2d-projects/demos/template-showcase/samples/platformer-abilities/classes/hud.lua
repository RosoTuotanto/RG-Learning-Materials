local hud = {}

--------------------------------------------------------------------------------------
-- Private functions

local function newPanel( parent, colors, cornerRadius )
	local panel = display.newRoundedRect( parent, 0, 0, 1, 1, cornerRadius )
	panel:setFillColor( unpack( colors.panel ) )

	return panel
end

local function newLabel( parent, text, font, fontSize, colors )
	local label = display.newText({ parent = parent, text = text, x = 0, y = 0, font = font, fontSize = fontSize })
	label:setFillColor( unpack( colors.text ) )

	return label
end

--------------------------------------------------------------------------------------
-- Public functions

-- iconSize is the pickup art's display size.
function hud.new( parent, settings, iconSize )
	local config = settings.hud
	local colors = settings.colors
	local text = settings.text
	local order = settings.abilityOrder

	local view = display.newGroup()
	parent:insert( view )

	-- Wider or taller screens would show the neighbouring rooms, so everything outside the content area is covered.
	local coverWidth = display.actualContentWidth * 4
	local coverHeight = display.actualContentHeight * 4
	local covers = {
		{ x = 0, y = display.contentCenterY, anchorX = 1, anchorY = 0.5 },
		{ x = display.contentWidth, y = display.contentCenterY, anchorX = 0, anchorY = 0.5 },
		{ x = display.contentCenterX, y = 0, anchorX = 0.5, anchorY = 1 },
		{ x = display.contentCenterX, y = display.contentHeight, anchorX = 0.5, anchorY = 0 },
	}

	for i = 1, #covers do
		local spot = covers[i]
		local cover = display.newRect( view, spot.x, spot.y, coverWidth, coverHeight )
		cover.anchorX, cover.anchorY = spot.anchorX, spot.anchorY
		cover:setFillColor( unpack( colors.sky ) )
	end

	-- The ability icons sit under the Back button, clear of both top corners.
	local abilityGroup = display.newGroup()
	view:insert( abilityGroup )

	local abilityPanel = newPanel( abilityGroup, colors, config.cornerRadius )
	abilityPanel.anchorX, abilityPanel.anchorY = 0, 0
	abilityPanel.width = config.padding + #order * ( iconSize + config.padding )
	abilityPanel.height = iconSize + config.padding * 2

	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	local icons = {}
	for i = 1, #order do
		local icon = display.newImageRect( abilityGroup, settings.abilities[order[i]].image, iconSize, iconSize )
		icon.x = config.padding + ( i - 1 ) * ( iconSize + config.padding ) + iconSize * 0.5
		icon.y = abilityPanel.height * 0.5
		icons[order[i]] = icon
	end

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	local hintGroup = display.newGroup()
	view:insert( hintGroup )

	local hintPanel = newPanel( hintGroup, colors, config.cornerRadius )
	hintPanel:setFillColor( unpack( colors.hintBackground ) )
	local hintWidth = 0
	local lineHeight = config.hintSize * config.hintLineHeight

	for i = 1, #text.hint do
		local line = newLabel( hintGroup, text.hint[i], settings.font.body, config.hintSize, colors )
		line.y = ( i - ( #text.hint + 1 ) * 0.5 ) * lineHeight
		hintWidth = math.max( hintWidth, line.width )
	end

	hintPanel.width = hintWidth + config.hintPadding * 2
	hintPanel.height = #text.hint * lineHeight + config.hintPadding * 2

	local messageGroup = display.newGroup()
	messageGroup.x, messageGroup.y = display.contentCenterX, display.contentCenterY - config.messageOffset
	view:insert( messageGroup )

	local messagePanel = newPanel( messageGroup, colors, config.cornerRadius )
	local message = newLabel( messageGroup, "", settings.font.heading, config.messageSize, colors )

	-- An ability icon is lit with a short pop once its pickup is collected.
	function view:light( name )
		local icon = icons[name]
		icon.alpha = 1
		icon.xScale, icon.yScale = config.popScale, config.popScale

		transition.to( icon, { xScale = 1, yScale = 1, time = config.popTime, tag = settings.tag } )
	end

	function view:dimAll()
		for i = 1, #order do
			local icon = icons[order[i]]
			icon.alpha = config.dimAlpha
			icon.xScale, icon.yScale = 1, 1
		end
	end

	-- A lasting message stays until hideMessage; any other fades out after a moment.
	function view:showMessage( shown, isLasting )
		transition.cancel( messageGroup )

		message.text = shown
		messagePanel.width = message.width + config.messagePadding * 2
		messagePanel.height = message.height + config.messagePadding
		messageGroup.alpha = 1
		messageGroup.isVisible = true

		if not isLasting then
			transition.to( messageGroup, { delay = config.messageTime, time = config.messageFadeTime, alpha = 0, tag = settings.tag } )
		end
	end

	function view:hideMessage()
		transition.cancel( messageGroup )
		messageGroup.isVisible = false
	end

	-- Call on resize: the ability panel and the hint follow the actual screen edges.
	function view:position()
		local top = display.screenOriginY

		abilityGroup.x = display.screenOriginX + config.left
		abilityGroup.y = top + config.top

		hintGroup.x = display.contentCenterX
		hintGroup.y = top + display.actualContentHeight - config.hintOffset
	end

	view:dimAll()
	view:hideMessage()
	view:position()

	return view
end

return hud
