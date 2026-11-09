-- The day's actions as buttons; an action already used today stays dimmed and ignores clicks and keys.

local actionMenu = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local button = require( "samples.visual-novel-life-sim.classes.button" )
local uiHelpers = require( "samples.visual-novel-life-sim.classes.uiHelpers" )
local storyPlayer = require( "samples.visual-novel-life-sim.classes.storyPlayer" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local menuMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

local function selectRow( menu, index )
	menu.selectedRow = index

	for i = 1, #menu.rows do
		button.setSelected( menu.rows[i], i == index )
	end
end

-- Moves the highlight by step, skipping the actions used today.
local function moveSelection( menu, step )
	local count = #menu.rows
	local index = menu.selectedRow

	repeat
		index = ( index - 1 + step ) % count + 1
	until not menu.rows[index].isUsed

	selectRow( menu, index )
end

local function onRowPress( row )
	if not row.isUsed then
		row.menu.onPick( row.index )
	end
end

--------------------------------------------------------------------------------------
-- Public functions

-- usedActions[index] is true for every action already taken today.
function menuMethods:open( usedActions )
	for i = 1, #self.rows do
		local row = self.rows[i]
		row.isUsed = usedActions[i] == true
		row.alpha = row.isUsed and self.layout.usedAlpha or 1
	end

	self.selectedRow = #self.rows
	moveSelection( self, 1 )
	self.group.isVisible = true
end

function menuMethods:close()
	self.group.isVisible = false
end

function menuMethods:isOpen()
	return self.group.isVisible
end

-- Returns true when the key was used.
function menuMethods:handleKey( keyName )
	if storyPlayer.isKeyIn( keyName, self.keys.up ) then
		moveSelection( self, -1 )

	elseif storyPlayer.isKeyIn( keyName, self.keys.down ) then
		moveSelection( self, 1 )

	elseif storyPlayer.isKeyIn( keyName, self.keys.confirm ) then
		onRowPress( self.rows[self.selectedRow] )

	else
		return false
	end
	return true
end

-- params: parent, layout (settings.actionMenu), actions, font, style, keys ( up, down, confirm ), onPick( actionIndex ).
function actionMenu.new( params )
	local layout = params.layout

	local menu = setmetatable( {
		layout = layout,
		keys = params.keys,
		onPick = params.onPick,
		rows = {},
		selectedRow = 1,
	}, { __index = menuMethods } )

	menu.group = display.newGroup()
	params.parent:insert( menu.group )

	-- Clicks anywhere on screen stay away from the story while the day's plan is open; the scene sizes it to the window.
	menu.blocker = display.newRect( menu.group, 0, 0, 1, 1 )
	menu.blocker.isVisible = false
	menu.blocker.isHitTestable = true
	menu.blocker:addEventListener( "touch", uiHelpers.blockTouch )

	for i = 1, #params.actions do
		local row = button.new({
			parent = menu.group,
			x = layout.x,
			y = layout.firstY + ( i - 1 ) * ( layout.height + layout.gap ),
			width = layout.width,
			height = layout.height,
			style = params.style,
			label = params.actions[i].label,
			font = params.font.heading,
			fontSize = layout.fontSize,
			onPress = onRowPress,
		})
		row.menu = menu
		row.index = i
		menu.rows[i] = row
	end

	menu.group.isVisible = false
	return menu
end

return actionMenu
