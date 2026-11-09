local hud = {}

--------------------------------------------------------------------------------------
-- Localised functions

local format = string.format

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

	local function newLabel( fontSize, font )
		local label = display.newText({ parent = view, text = "", x = 0, y = 0, font = font, fontSize = fontSize })
		label:setFillColor( unpack( colors.text ) )

		return label
	end

	-- The counters sit under the Back button, clear of both top corners.
	local deathsLabel = newLabel( config.labelSize, settings.font.heading )
	deathsLabel.anchorX = 0

	local timeLabel = newLabel( config.labelSize, settings.font.heading )
	timeLabel.anchorX = 0

	local hintBackground = display.newRect( view, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hints = {}
	for i = 1, #text.hint do
		hints[i] = newLabel( config.hintSize, settings.font.body )
		hints[i].text = text.hint[i]
		hints[i]:setFillColor( unpack( colors.hintText ) )
	end

	local message = newLabel( config.messageSize, settings.font.heading )
	message.text = text.complete
	message.x, message.y = display.contentCenterX, display.contentCenterY
	message.isVisible = false

	function view:setDeaths( count )
		deathsLabel.text = text.deaths .. count
	end

	-- Setting text redraws its texture, so it only changes when the shown tenth of a second does.
	function view:setTime( milliseconds )
		local shown = text.time .. format( "%.1f", milliseconds / 1000 )
		if timeLabel.text ~= shown then
			timeLabel.text = shown
		end
	end

	function view:showMessage( isShown )
		message.isVisible = isShown
	end

	-- Call on resize: the counters and the hint follow the actual screen edges.
	function view:position()
		local left = display.screenOriginX + config.left
		local top = display.screenOriginY
		local bottom = top + display.actualContentHeight

		deathsLabel.x, deathsLabel.y = left, top + config.deathsOffset
		timeLabel.x, timeLabel.y = left, top + config.timeOffset

		for i = 1, #hints do
			hints[i].x, hints[i].y = display.contentCenterX, bottom - config.hintOffsets[i]
		end

		fitBackground( hintBackground, hints, config.hintPadding )
	end

	view:position()

	return view
end

return hud
