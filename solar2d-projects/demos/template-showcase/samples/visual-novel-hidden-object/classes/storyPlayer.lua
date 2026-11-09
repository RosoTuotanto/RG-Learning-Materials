-- Plays a Weaver story: background, characters, a speaker label, the text box and choice buttons.

local storyPlayer = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local weaver = require( "samples.visual-novel-hidden-object.libs.spyricStoryWeaver" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local playerMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

local function newPixelImage( parent, path, width, height )
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	local image = display.newImageRect( parent, path, width, height )

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )
	return image
end

local function setBackground( player, path )
	display.remove( player.background )
	player.background = nil

	if path then
		local layout = player.layout.background
		player.background = newPixelImage( player.backgroundLayer, path, layout.width, layout.height )
		player.background.x = layout.x
		player.background.y = layout.y
		-- Idea: start a music track that belongs to this background here.
	end
end

local function removeCharacters( player )
	for name, character in pairs( player.characters ) do
		display.remove( character )
		player.characters[name] = nil
	end
end

-- Arguments come from <<character, show|hide, name, x = ..., xScale = ...>>; Weaver keeps "-1" as a string.
local function setCharacter( player, row )
	local layout = player.layout
	local name = row[3]
	local character = player.characters[name]

	if row[2] == "hide" then
		display.remove( character )
		player.characters[name] = nil
		return
	end

	if not character then
		-- Idea: add more poses and expressions by passing one more argument and loading "<name>_<pose>.png".
		local path = layout.characterFolder .. name .. ".png"
		character = newPixelImage( player.characterLayer, path, layout.characterWidth * layout.characterScale, layout.characterHeight * layout.characterScale )
		character.anchorY = 1
		player.characters[name] = character
	end

	character.x = tonumber( row.x ) or layout.background.x
	character.y = layout.background.y + layout.background.height * 0.5
	character.xScale = tonumber( row.xScale ) or 1
end

local function clearChoices( player )
	for i = #player.choices, 1, -1 do
		display.remove( player.choices[i] )
		player.choices[i] = nil
	end
end

local function highlightChoice( player, index )
	local layout = player.layout.choices
	player.selectedChoice = index

	for i = 1, #player.choices do
		local colour = i == index and layout.selectedColour or layout.fillColour
		player.choices[i].box:setFillColor( unpack( colour ) )
	end
end

local function onChoiceTouch( event )
	if event.phase == "began" then
		local button = event.target
		button.player:choose( button.index )
	end
	return true
end

-- Every link row right after the shown text becomes a button.
local function showChoices( player )
	local layout = player.layout.choices
	local rows = player.rows

	while rows[player.rowIndex] and rows[player.rowIndex][1] == "link" do
		local row = rows[player.rowIndex]
		player.rowIndex = player.rowIndex + 1

		local index = #player.choices + 1
		local button = display.newGroup()
		player.choiceLayer:insert( button )
		button.x = layout.x
		button.y = layout.y + ( index - 1 ) * ( layout.height + layout.gap )

		button.box = display.newRoundedRect( button, 0, 0, layout.width, layout.height, layout.cornerRadius )
		button.label = display.newText( button, row[2], 0, 0, player.layout.font.heading, layout.fontSize )

		button.player = player
		button.index = index
		button.target = row[3]
		button:addEventListener( "touch", onChoiceTouch )
		player.choices[index] = button

		-- A sample can add its own content to the button, such as what the choice will change.
		if player.decorateChoice then
			player.decorateChoice( button )
		end
	end

	if #player.choices > 0 then
		highlightChoice( player, 1 )
	end
end

local function runCommand( player, row )
	local name = row[1]

	if name == "img" then
		setBackground( player, row[2] )

	elseif name == "del" then
		setBackground( player, nil )

	elseif name == "character" then
		setCharacter( player, row )

	elseif name == "speaker" then
		player.speakerText.text = row[2] or ""

	elseif name == "jump" then
		player:jumpTo( row[2] )
		return true

	elseif player.commands[name] then
		local rows = player.rows
		local pauses = player.commands[name]( row, player )

		-- A handler that called jumpTo has already moved the story on.
		if player.rows ~= rows then
			return true
		end

		-- A handler that returns true pauses the story until the scene calls player:resume().
		if pauses then
			player.isPaused = true
			return true
		end

	else
		print( "storyPlayer: no handler for the <<" .. tostring( name ) .. ">> command." )
	end
	return false
end

local function clearStage( player )
	removeCharacters( player )
	clearChoices( player )
	player.speakerText.text = ""
	player.bodyText.text = ""
end

local function onSensorTouch( event )
	local player = event.target.player

	if event.phase == "began" then
		player:advance()
	end

	-- An inactive story lets touches through to whatever the sample shows instead.
	return player.isActive
end

--------------------------------------------------------------------------------------
-- Public functions

function storyPlayer.isKeyIn( keyName, keyList )
	for i = 1, #keyList do
		if keyList[i] == keyName then
			return true
		end
	end
	return false
end

-- Sizes a full-screen rect to the actual screen; call it again on resize, as the window may have changed.
function storyPlayer.coverScreen( object )
	object.x = display.screenOriginX + display.actualContentWidth * 0.5
	object.y = display.screenOriginY + display.actualContentHeight * 0.5
	object.width = display.actualContentWidth
	object.height = display.actualContentHeight
end

-- Shows rows until the next line of text, then waits; calls onEnd when the passage runs out.
function playerMethods:continue()
	self.isPaused = false

	while self.rowIndex <= #self.rows do
		local row = self.rows[self.rowIndex]

		if row[1] == "text" then
			self.rowIndex = self.rowIndex + 1
			self.bodyText.text = row[2]
			showChoices( self )
			return

		elseif row[1] == "link" then
			showChoices( self )
			return
		end

		self.rowIndex = self.rowIndex + 1
		if runCommand( self, row ) then
			return
		end
	end

	self.isActive = false
	if self.onEnd then
		self.onEnd( self )
	end
end

function playerMethods:jumpTo( passageName )
	local rows = weaver.getNode( passageName, self.storyName )
	if not rows then
		error( "storyPlayer: passage \"" .. tostring( passageName ) .. "\" could not be read from " .. self.storyName .. "." )
	end

	-- Idea: store passageName with the template's save system here, so the story continues where the player left off.
	clearStage( self )

	self.rows = rows
	self.rowIndex = 1
	self.isActive = true
	self:continue()
end

-- Picks up a story paused by a command handler; a second call in the same frame does nothing.
function playerMethods:resume()
	if self.isPaused then
		self:continue()
	end
end

function playerMethods:advance()
	if self.isActive and not self.isPaused and #self.choices == 0 then
		self:continue()
	end
end

function playerMethods:choose( index )
	local button = self.choices[index]
	if button then
		local target = button.target
		clearChoices( self )
		self:jumpTo( target )
	end
end

function playerMethods:isConfirmKey( keyName )
	return storyPlayer.isKeyIn( keyName, self.layout.keys.confirm )
end

-- Returns true when the key was used, so the scene can ignore it.
function playerMethods:handleKey( keyName )
	local keys = self.layout.keys
	local choiceCount = #self.choices

	if choiceCount > 0 then
		if storyPlayer.isKeyIn( keyName, keys.up ) then
			highlightChoice( self, ( self.selectedChoice - 2 ) % choiceCount + 1 )
			return true

		elseif storyPlayer.isKeyIn( keyName, keys.down ) then
			highlightChoice( self, self.selectedChoice % choiceCount + 1 )
			return true

		elseif storyPlayer.isKeyIn( keyName, keys.confirm ) then
			self:choose( self.selectedChoice )
			return true
		end

	elseif storyPlayer.isKeyIn( keyName, keys.confirm ) then
		self:advance()
		return true
	end
	return false
end

-- Clears the stage so a fresh story can start.
function playerMethods:reset()
	setBackground( self, nil )
	clearStage( self )
	self.isActive = false
	self.isPaused = false
end

function playerMethods:fitToScreen()
	storyPlayer.coverScreen( self.sensor )
end

function playerMethods:destroy()
	display.remove( self.group )
	self.group = nil
	self.sensor = nil
	self.characters = nil
	self.choices = nil
end

-- params: parent, storyName, layout (settings.player), commands ( name = function( row, player ) ), onEnd( player ), and optionally decorateChoice( button ).
function storyPlayer.new( params )
	local layout = params.layout
	local box = layout.textBox

	local player = setmetatable( {
		layout = layout,
		storyName = params.storyName,
		commands = params.commands or {},
		onEnd = params.onEnd,
		decorateChoice = params.decorateChoice,
		characters = {},
		choices = {},
		rows = {},
		rowIndex = 1,
		isActive = false,
		isPaused = false,
	}, { __index = playerMethods } )

	-- A sample's own layers go above player.group, or the sample hides the group while it takes over.
	player.group = display.newGroup()
	params.parent:insert( player.group )

	player.backgroundLayer = display.newGroup()
	player.characterLayer = display.newGroup()
	player.group:insert( player.backgroundLayer )
	player.group:insert( player.characterLayer )

	-- Covers the whole screen so a click anywhere advances the story.
	player.sensor = display.newRect( player.group, 0, 0, 1, 1 )
	player.sensor.isVisible = false
	player.sensor.isHitTestable = true
	player.sensor.player = player
	player.sensor:addEventListener( "touch", onSensorTouch )
	player:fitToScreen()

	local boxLeft = box.x - box.width * 0.5
	local boxTop = box.y - box.height * 0.5
	local textBox = display.newRoundedRect( player.group, box.x, box.y, box.width, box.height, box.cornerRadius )
	textBox:setFillColor( unpack( box.fillColour ) )

	player.speakerText = display.newText( player.group, "", boxLeft + box.padding, boxTop + box.padding * 0.5, layout.font.heading, box.speakerSize )
	player.speakerText.anchorX = 0
	player.speakerText.anchorY = 0
	player.speakerText:setFillColor( unpack( box.speakerColour ) )

	player.bodyText = display.newText({
		parent = player.group,
		text = "",
		x = boxLeft + box.padding,
		y = boxTop + box.bodyOffset,
		width = box.width - box.padding * 2,
		font = layout.font.body,
		fontSize = box.bodySize,
	})
	player.bodyText.anchorX = 0
	player.bodyText.anchorY = 0

	player.choiceLayer = display.newGroup()
	player.group:insert( player.choiceLayer )

	return player
end

return storyPlayer
