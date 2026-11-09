-- The evidence list with each item's description, picked with a click or with Up, Down and Enter, and the clue being presented on stage.

local evidencePanel = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local button = require( "samples.visual-novel-interrogation.classes.button" )
local storyPlayer = require( "samples.visual-novel-interrogation.classes.storyPlayer" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local panelMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

local function selectRow( panel, index )
	panel.selectedRow = index

	for i = 1, #panel.rows do
		button.setSelected( panel.rows[i], i == index )
	end
end

local function onRowPress( row )
	row.panel.onPick( row.index )
end

-- Keeps clicks on the panel and around it from reaching the testimony buttons underneath.
local function blockTouch()
	return true
end

local function onClosePress( closeButton )
	closeButton.panel:close()
end

--------------------------------------------------------------------------------------
-- Public functions

function panelMethods:open()
	selectRow( self, 1 )
	self.group.isVisible = true
end

function panelMethods:close()
	self.group.isVisible = false
end

-- Shows the clue between the characters while it is being presented.
function panelMethods:showPresented( clueIndex )
	self:hidePresented()
	self.presented[clueIndex].isVisible = true
end

function panelMethods:hidePresented()
	for i = 1, #self.presented do
		self.presented[i].isVisible = false
	end
end

function panelMethods:isOpen()
	return self.group.isVisible
end

-- Returns true when the key was used.
function panelMethods:handleKey( keyName )
	local rowCount = #self.rows

	if storyPlayer.isKeyIn( keyName, self.keys.up ) then
		selectRow( self, ( self.selectedRow - 2 ) % rowCount + 1 )

	elseif storyPlayer.isKeyIn( keyName, self.keys.down ) then
		selectRow( self, self.selectedRow % rowCount + 1 )

	elseif storyPlayer.isKeyIn( keyName, self.keys.confirm ) then
		self.onPick( self.selectedRow )

	elseif storyPlayer.isKeyIn( keyName, self.keys.close ) then
		self:close()

	else
		return false
	end
	return true
end

-- params: parent, layout (settings.evidencePanel), presented (settings.presentedClue), clues, clueFolder, font, style,
-- keys ( up, down, confirm, close ), onPick( clueIndex ).
function evidencePanel.new( params )
	local layout = params.layout

	-- The clue sprites are pixel art.
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	local panel = setmetatable( {
		keys = params.keys,
		onPick = params.onPick,
		rows = {},
		presented = {},
		selectedRow = 1,
	}, { __index = panelMethods } )

	for i = 1, #params.clues do
		local clue = params.clues[i]
		local scale = params.presented.scale
		local image = display.newImageRect( params.parent, params.clueFolder .. clue.id .. ".png", clue.width * scale, clue.height * scale )
		image.x = params.presented.x
		image.y = params.presented.y
		image.isVisible = false
		panel.presented[i] = image
	end

	panel.group = display.newGroup()
	params.parent:insert( panel.group )

	-- Full-screen; the scene sizes it to the window.
	panel.backdrop = display.newRect( panel.group, 0, 0, 1, 1 )
	panel.backdrop:setFillColor( unpack( layout.backdropColour ) )
	panel.backdrop:addEventListener( "touch", blockTouch )

	local box = display.newRoundedRect( panel.group, layout.x, layout.y, layout.width, layout.height, layout.cornerRadius )
	box:setFillColor( unpack( layout.fillColour ) )
	box:addEventListener( "touch", blockTouch )

	local top = layout.y - layout.height * 0.5
	local title = display.newText( panel.group, layout.title, layout.x, top + layout.titleOffset, params.font.heading, layout.titleSize )
	title:setFillColor( unpack( layout.titleColour ) )

	local closeButton = button.new({
		parent = panel.group,
		x = layout.x + layout.width * 0.5 - layout.closeInset - layout.closeWidth * 0.5,
		y = top + layout.titleOffset,
		width = layout.closeWidth,
		height = layout.closeHeight,
		style = params.style,
		label = layout.closeLabel,
		font = params.font.heading,
		fontSize = layout.nameSize,
		onPress = onClosePress,
	})
	closeButton.panel = panel

	for i = 1, #params.clues do
		local clue = params.clues[i]

		local row = button.new({
			parent = panel.group,
			x = layout.x,
			y = top + layout.firstRowOffset + ( i - 1 ) * layout.rowSpacing,
			width = layout.rowWidth,
			height = layout.rowHeight,
			style = params.style,
			onPress = onRowPress,
		})
		row.panel = panel
		row.index = i

		local sprite = display.newImageRect( row, params.clueFolder .. clue.id .. ".png", clue.width, clue.height )
		sprite.x = layout.spriteOffset

		local name = display.newText( row, clue.name, layout.nameOffset, layout.nameY, params.font.heading, layout.nameSize )
		name.anchorX = 0

		-- Each item says what it shows, so the player can read it against a statement.
		local description = display.newText({
			parent = row,
			text = clue.description,
			x = layout.nameOffset,
			y = layout.descriptionY,
			width = layout.descriptionWidth,
			font = params.font.body,
			fontSize = layout.descriptionSize,
			align = "left",
		})
		description.anchorX = 0
		description.anchorY = 0
		description:setFillColor( unpack( layout.descriptionColour ) )

		panel.rows[i] = row
	end

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	panel.group.isVisible = false
	return panel
end

return evidencePanel
