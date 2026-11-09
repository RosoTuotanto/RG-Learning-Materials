-- Every relationship with a head-and-shoulders portrait, its value and a bar that grows from the centre.

local relationshipsPanel = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local button = require( "samples.visual-novel-life-sim.classes.button" )
local uiHelpers = require( "samples.visual-novel-life-sim.classes.uiHelpers" )
local storyPlayer = require( "samples.visual-novel-life-sim.classes.storyPlayer" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local panelMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

local function onClosePress( closeButton )
	closeButton.panel:close()
end

local function setRow( panel, row, value )
	local layout = panel.layout
	local isNegative = value < 0

	row.valueText.text = tostring( value )
	row.fill.width = layout.barWidth * 0.5 * math.abs( value ) / panel.range.max
	row.fill.anchorX = isNegative and 1 or 0
	row.fill:setFillColor( unpack( isNegative and layout.negativeColour or layout.positiveColour ) )
end

local function newRow( panel, relationship, params, left, y )
	local layout = panel.layout
	local right = left + layout.width

	-- One image sheet frame cuts the head and shoulders out of the full portrait.
	local sheet = graphics.newImageSheet( params.imageFolder .. relationship.image .. ".png", { frames = { layout.crop } } )
	local portrait = display.newImageRect( panel.group, sheet, 1, layout.portraitSize, layout.portraitSize )
	portrait.x = left + layout.portraitOffset
	portrait.y = y

	local name = display.newText( panel.group, relationship.name, left + layout.textOffset, y - layout.barOffset * 0.5, params.font.heading, layout.nameSize )
	name.anchorX = 0

	local barX = left + layout.textOffset + layout.barWidth * 0.5
	local track = display.newRect( panel.group, barX, y + layout.barOffset, layout.barWidth, layout.barHeight )
	track:setFillColor( unpack( layout.trackColour ) )

	local valueText = display.newText( panel.group, "", right - layout.valueInset, y, params.font.heading, layout.valueSize )
	valueText.anchorX = 1

	return {
		id = relationship.id,
		valueText = valueText,
		fill = display.newRect( panel.group, barX, y + layout.barOffset, layout.barWidth, layout.barHeight ),
	}
end

--------------------------------------------------------------------------------------
-- Public functions

-- values holds each relationship's current value by id.
function panelMethods:open( values )
	for i = 1, #self.rows do
		local row = self.rows[i]
		setRow( self, row, values[row.id] )
	end

	self.group.isVisible = true
end

function panelMethods:close()
	self.group.isVisible = false
end

function panelMethods:isOpen()
	return self.group.isVisible
end

-- Returns true when the key was used.
function panelMethods:handleKey( keyName )
	if storyPlayer.isKeyIn( keyName, self.keys.close ) then
		self:close()
		return true
	end
	return false
end

-- params: parent, layout (settings.relationshipsPanel), relationships, range, imageFolder, font, style, keys ( close ).
function relationshipsPanel.new( params )
	local layout = params.layout

	local panel = setmetatable( {
		layout = layout,
		range = params.range,
		keys = params.keys,
		rows = {},
	}, { __index = panelMethods } )

	panel.group = display.newGroup()
	params.parent:insert( panel.group )

	-- Full-screen; the scene sizes it to the window.
	panel.backdrop = display.newRect( panel.group, 0, 0, 1, 1 )
	panel.backdrop:setFillColor( unpack( layout.backdropColour ) )
	panel.backdrop:addEventListener( "touch", uiHelpers.blockTouch )

	local box = display.newRoundedRect( panel.group, layout.x, layout.y, layout.width, layout.height, layout.cornerRadius )
	box:setFillColor( unpack( layout.fillColour ) )

	local left = layout.x - layout.width * 0.5
	local top = layout.y - layout.height * 0.5

	local title = display.newText( panel.group, layout.title, layout.x, top + layout.titleOffset, params.font.heading, layout.titleSize )
	title:setFillColor( unpack( layout.titleColour ) )

	local closeButton = button.new({
		parent = panel.group,
		x = left + layout.width - layout.closeInset - layout.closeWidth * 0.5,
		y = top + layout.titleOffset,
		width = layout.closeWidth,
		height = layout.closeHeight,
		style = params.style,
		label = layout.closeLabel,
		font = params.font.heading,
		fontSize = layout.closeFontSize,
		onPress = onClosePress,
	})
	closeButton.panel = panel

	uiHelpers.withPixelFilter( function()
		for i = 1, #params.relationships do
			local y = top + layout.firstRowOffset + ( i - 1 ) * layout.rowSpacing
			panel.rows[i] = newRow( panel, params.relationships[i], params, left, y )
		end
	end )

	panel.group.isVisible = false
	return panel
end

return relationshipsPanel
