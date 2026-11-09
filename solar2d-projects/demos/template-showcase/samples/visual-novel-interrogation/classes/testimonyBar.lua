-- Testimony controls: the action buttons, the statement counter and the contradiction marks.

local testimonyBar = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local button = require( "samples.visual-novel-interrogation.classes.button" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local barMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

local function onActionPress( target )
	target.actions[target.action]()
end

-- Keeps clicks from reaching the story player, which would advance past the statement.
local function blockTouch()
	return true
end

local function newMarks( parent, layout, font, count )
	local group = display.newGroup()
	parent:insert( group )

	local label = display.newText( group, layout.label, layout.x, layout.labelY, font.body, layout.labelSize )
	label.anchorX = 0

	group.marks = {}
	for i = 1, count do
		local mark = display.newCircle( group, layout.x + layout.radius + ( i - 1 ) * layout.spacing, layout.markY, layout.radius )
		mark:setStrokeColor( unpack( layout.strokeColour ) )
		mark.strokeWidth = layout.strokeWidth
		group.marks[i] = mark
	end
	return group
end

--------------------------------------------------------------------------------------
-- Public functions

function barMethods:setVisible( isVisible )
	self.controls.isVisible = isVisible
end

function barMethods:setStatement( index, count )
	self.counter.text = string.format( self.layout.counterFormat, index, count )
end

function barMethods:setMarksVisible( isVisible )
	self.marks.isVisible = isVisible
end

-- The marks sit under the app's Back button, so they follow the window's top-left corner.
function barMethods:positionMarks()
	self.marks.x = display.screenOriginX
	self.marks.y = display.screenOriginY
end

-- Fills the first count marks; when a mark was just filled, it pops so the find is noticed.
function barMethods:setFound( count, isNew )
	local layout = self.marksLayout
	local marks = self.marks.marks

	for i = 1, #marks do
		marks[i]:setFillColor( unpack( i <= count and layout.foundColour or layout.openColour ) )
		marks[i].xScale = 1
		marks[i].yScale = 1
	end

	if isNew and marks[count] then
		transition.from( marks[count], { xScale = layout.popScale, yScale = layout.popScale, time = layout.popTime, tag = layout.transitionTag } )
	end
end

-- params: parent, layout (settings.testimony), marks (settings.contradictions), markCount, font, style, actions ( name = function ).
function testimonyBar.new( params )
	local layout = params.layout

	local bar = setmetatable( {
		layout = layout,
		marksLayout = params.marks,
	}, { __index = barMethods } )

	bar.controls = display.newGroup()
	params.parent:insert( bar.controls )

	-- Full-screen; the scene sizes it to the window.
	bar.blocker = display.newRect( bar.controls, 0, 0, 1, 1 )
	bar.blocker.isVisible = false
	bar.blocker.isHitTestable = true
	bar.blocker:addEventListener( "touch", blockTouch )

	local buttonCount = #layout.buttons
	local rowWidth = buttonCount * layout.buttonWidth + ( buttonCount - 1 ) * layout.gap
	local firstX = display.contentCenterX - rowWidth * 0.5 + layout.buttonWidth * 0.5

	for i = 1, buttonCount do
		local definition = layout.buttons[i]

		local actionButton = button.new({
			parent = bar.controls,
			x = firstX + ( i - 1 ) * ( layout.buttonWidth + layout.gap ),
			y = layout.y,
			width = layout.buttonWidth,
			height = layout.buttonHeight,
			style = params.style,
			isSelected = definition.isPrimary,
			label = definition.label,
			font = params.font.heading,
			onPress = onActionPress,
		})
		actionButton.action = definition.action
		actionButton.actions = params.actions
	end

	bar.counter = display.newText( bar.controls, "", layout.counterX, layout.counterY, params.font.body, layout.counterSize )
	bar.counter.anchorX = 1
	bar.counter.anchorY = 0
	bar.counter:setFillColor( unpack( layout.counterColour ) )

	bar.marks = newMarks( params.parent, params.marks, params.font, params.markCount )
	bar:positionMarks()

	return bar
end

return testimonyBar
