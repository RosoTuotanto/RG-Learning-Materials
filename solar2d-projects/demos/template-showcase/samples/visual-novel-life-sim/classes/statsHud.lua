-- The day counter, a bar with its value and last change per stat, and the Relationships button, in one panel below the Back to Menu button.

local statsHud = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local button = require( "samples.visual-novel-life-sim.classes.button" )
local uiHelpers = require( "samples.visual-novel-life-sim.classes.uiHelpers" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local hudMethods = {}

--------------------------------------------------------------------------------------
-- Public functions

-- The panel sits under the app's Back button, so it follows the window's top-left corner.
function hudMethods:position()
	self.group.x = display.screenOriginX + self.layout.x
	self.group.y = display.screenOriginY + self.layout.y
end

function hudMethods:setDay( day, dayCount )
	self.dayText.text = string.format( self.layout.dayFormat, day, dayCount )
end

-- Slides the bar to the new value when isAnimated is true, otherwise sets it at once; the number changes at once.
function hudMethods:setStat( id, value, isAnimated )
	local layout = self.layout
	local fill = self.bars[id]
	local width = layout.barWidth * ( value - self.range.min ) / ( self.range.max - self.range.min )

	self.values[id].text = tostring( value )
	transition.cancel( fill )

	if isAnimated then
		transition.to( fill, { width = width, time = layout.barTime, tag = layout.transitionTag } )
	else
		fill.width = width
	end
end

-- Adds to the change shown beside a bar, so several rows of one choice add up.
function hudMethods:addChange( id, amount )
	self.changes[id] = self.changes[id] + amount
	uiHelpers.setChangeText( self.changeTexts[id], self.changes[id], self.layout )
end

function hudMethods:clearChanges()
	for id, changeText in pairs( self.changeTexts ) do
		self.changes[id] = 0
		changeText.text = ""
	end
end

-- params: parent, layout (settings.hud), stats, range, imageFolder, font, style, onRelationships( button ).
function statsHud.new( params )
	local layout = params.layout

	local hud = setmetatable( {
		layout = layout,
		range = params.range,
		bars = {},
		values = {},
		changes = {},
		changeTexts = {},
	}, { __index = hudMethods } )

	hud.group = display.newGroup()
	params.parent:insert( hud.group )
	hud:position()

	local panel = display.newRoundedRect( hud.group, 0, 0, layout.width, layout.height, layout.cornerRadius )
	panel.anchorX = 0
	panel.anchorY = 0
	panel:setFillColor( unpack( layout.fillColour ) )
	panel:addEventListener( "touch", uiHelpers.blockTouch )

	hud.dayText = display.newText( hud.group, "", layout.padding, layout.padding, params.font.heading, layout.dayFontSize )
	hud.dayText.anchorX = 0
	hud.dayText.anchorY = 0
	hud.dayText:setFillColor( unpack( layout.dayColour ) )

	for i = 1, #params.stats do
		local stat = params.stats[i]
		local y = layout.firstRowOffset + ( i - 1 ) * layout.rowSpacing

		uiHelpers.withPixelFilter( function()
			local icon = display.newImageRect( hud.group, params.imageFolder .. stat.icon, layout.iconSize, layout.iconSize )
			icon.x = layout.padding + layout.iconSize * 0.5
			icon.y = y
		end )

		local track = display.newRect( hud.group, layout.padding + layout.barOffset, y, layout.barWidth, layout.barHeight )
		track.anchorX = 0
		track:setFillColor( unpack( layout.trackColour ) )

		local fill = display.newRect( hud.group, track.x, y, layout.barWidth, layout.barHeight )
		fill.anchorX = 0
		fill:setFillColor( unpack( layout.barColour ) )
		hud.bars[stat.id] = fill

		local barEnd = track.x + layout.barWidth
		local value = display.newText( hud.group, "", barEnd + layout.valueOffset, y, params.font.heading, layout.valueFontSize )
		value.anchorX = 1
		hud.values[stat.id] = value

		local change = display.newText( hud.group, "", barEnd + layout.changeOffset, y, params.font.heading, layout.valueFontSize )
		change.anchorX = 0
		hud.changeTexts[stat.id] = change
		hud.changes[stat.id] = 0
	end

	button.new({
		parent = hud.group,
		x = layout.width * 0.5,
		y = layout.buttonOffset,
		width = layout.width - layout.padding * 2,
		height = layout.buttonHeight,
		style = params.style,
		label = layout.buttonLabel,
		font = params.font.heading,
		fontSize = layout.buttonFontSize,
		onPress = params.onRelationships,
	})

	return hud
end

return statsHud
