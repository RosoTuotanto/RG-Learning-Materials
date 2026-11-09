-- Screen-fixed lap times, a short message line and the hint, kept outside the group the camera moves.

local hud = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local laps = require( "samples.top-down-racing.classes.laps" )

--------------------------------------------------------------------------------------
-- Private functions

local function formatOrBlank( seconds, blank )
	if seconds then
		return laps.formatTime( seconds )
	end

	return blank
end

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

-- settings is the whole data/settings.lua table.
function hud.new( parent, settings )
	local style = settings.hud
	local colors = settings.colors
	local text = settings.text

	local overlay = display.newGroup()
	parent:insert( overlay )

	local times = display.newGroup()
	overlay:insert( times )

	local labels = {}
	local names = { "lap", "last", "best", "message" }

	for i = 1, #names do
		local label = display.newText({
			parent = times,
			text = "",
			x = 0,
			y = ( i - 1 ) * style.lineHeight,
			font = i == 1 and settings.font.heading or settings.font.body,
			fontSize = style.labelSize,
		})
		label.anchorX, label.anchorY = 0, 0
		label:setFillColor( unpack( colors.text ) )

		labels[names[i]] = label
	end

	labels.message:setFillColor( unpack( colors.message ) )

	local hintBackground = display.newRect( overlay, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hintLines = {}
	for i = 1, #text.hint do
		local line = display.newText({
			parent = overlay,
			text = text.hint[i],
			font = settings.font.body,
			fontSize = style.hintSize,
		})
		line:setFillColor( unpack( colors.text ) )

		hintLines[i] = line
	end

	-- Milliseconds left before the message line clears.
	local messageTimeLeft = 0

	-- Milliseconds left before the lap highlight ends, and the labels it lights up.
	local highlightTimeLeft = 0
	local highlighted = {}

	local function setHighlightColor( color )
		for i = 1, #highlighted do
			highlighted[i]:setFillColor( unpack( color ) )
		end
	end

	function overlay:setTimes( current, last, best )
		labels.lap.text = text.lap .. laps.formatTime( current )
		labels.last.text = text.last .. formatOrBlank( last, text.noTime )
		labels.best.text = text.best .. formatOrBlank( best, text.noTime )
	end

	function overlay:showMessage( message )
		labels.message.text = message
		messageTimeLeft = style.messageTime
	end

	-- Lights up the new last time, and the best time too when the lap improved it, at the moment the lap sound plays.
	function overlay:highlightLap( isBest )
		setHighlightColor( colors.text )

		highlighted = isBest and { labels.last, labels.best } or { labels.last }
		setHighlightColor( colors.lapHighlight )
		highlightTimeLeft = style.highlightTime
	end

	function overlay:update( deltaTime )
		if highlightTimeLeft > 0 then
			highlightTimeLeft = highlightTimeLeft - deltaTime

			if highlightTimeLeft <= 0 then
				setHighlightColor( colors.text )
			end
		end

		if messageTimeLeft > 0 then
			messageTimeLeft = messageTimeLeft - deltaTime

			if messageTimeLeft <= 0 then
				labels.message.text = ""
			end
		end
	end

	-- The times sit top-left under the app's back button, clear of the volume slider in the top-right corner.
	function overlay:position()
		times.x = display.screenOriginX + style.margin
		times.y = display.screenOriginY + style.margin + style.backHeight + style.gap

		local bottom = display.screenOriginY + display.actualContentHeight - style.hintBottom
		for i = 1, #hintLines do
			hintLines[i].x = display.contentCenterX
			hintLines[i].y = bottom - ( #hintLines - i ) * style.hintLineHeight
		end

		fitBackground( hintBackground, hintLines, style.hintPadding )
	end

	overlay:setTimes( 0 )
	overlay:position()

	return overlay
end

return hud
