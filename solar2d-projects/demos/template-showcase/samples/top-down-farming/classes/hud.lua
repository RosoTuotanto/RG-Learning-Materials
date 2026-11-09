-- The day and harvest counts under the app's back button, and the hint lines above the tool bar.

local hud = {}

--------------------------------------------------------------------------------------
-- Private functions

local function newLabel( parent, text, y, font, fontSize, color )
	local label = display.newText({
		parent = parent,
		text = text,
		x = display.contentCenterX,
		y = y,
		font = font,
		fontSize = fontSize,
	})
	label:setFillColor( unpack( color ) )

	return label
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

	local dayLabel = newLabel( overlay, "", 0, settings.font.heading, style.labelSize, colors.text )
	dayLabel.anchorX, dayLabel.anchorY = 0, 0

	local harvestLabel = newLabel( overlay, "", 0, settings.font.body, style.labelSize, colors.text )
	harvestLabel.anchorX, harvestLabel.anchorY = 0, 0

	local hintBackground = display.newRect( overlay, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hintLine = newLabel( overlay, text.hint, style.hintY, settings.font.body, style.hintSize, colors.hintText )
	local goalLine = newLabel( overlay, text.goal, style.goalY, settings.font.body, style.hintSize, colors.hintText )
	fitBackground( hintBackground, { hintLine, goalLine }, style.hintPadding )

	function overlay:update( day, harvestCount )
		dayLabel.text = string.format( text.day, day )
		harvestLabel.text = string.format( text.harvest, harvestCount )
	end

	-- The counts follow the app's back button, which sits at the actual screen corner.
	function overlay:position()
		local left = display.screenOriginX + style.margin
		local top = display.screenOriginY + style.margin + style.backHeight + style.gap

		dayLabel.x, dayLabel.y = left, top
		harvestLabel.x, harvestLabel.y = left, top + style.lineSpacing
	end

	overlay:position()

	return overlay
end

return hud
