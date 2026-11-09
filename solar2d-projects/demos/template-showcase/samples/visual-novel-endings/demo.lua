-- A short detective story with three endings; found endings stay unlocked between launches.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local json = require( "json" )
local weaver = require( "samples.visual-novel-endings.libs.spyricStoryWeaver" )
local storyPlayer = require( "samples.visual-novel-endings.classes.storyPlayer" )
local settings = require( "samples.visual-novel-endings.data.settings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local player
local hintText
local hintBackground
local endingsScreen
local endingRows = {}
local foundEndings = {}

--------------------------------------------------------------------------------------
-- Functions

local function loadFoundEndings()
	local path = system.pathForFile( settings.saveFile, system.DocumentsDirectory )
	local file = io.open( path, "r" )

	-- No file yet means no ending has been found.
	if not file then
		return {}
	end

	local contents = file:read( "*a" )
	io.close( file )
	return json.decode( contents ) or {}
end

local function saveFoundEndings()
	local path = system.pathForFile( settings.saveFile, system.DocumentsDirectory )
	local file = io.open( path, "w" )

	if file then
		file:write( json.encode( foundEndings ) )
		io.close( file )
	else
		print( "visual-novel-endings: could not write " .. tostring( path ) )
	end
end

-- Handler for <<ending, id>>, which every ending passage runs first.
local function onEnding( row )
	foundEndings[row[2]] = true
	saveFoundEndings()
	return false
end

local function showEndingsScreen()
	local layout = settings.endingsScreen

	for i = 1, #settings.endings do
		local ending = settings.endings[i]
		local rowText = endingRows[i]

		-- Idea: show a picture for each found ending here to turn this list into a gallery.
		if foundEndings[ending.id] then
			rowText.text = ending.title
			rowText:setFillColor( unpack( layout.foundColour ) )
		else
			rowText.text = layout.unknownTitle
			rowText:setFillColor( unpack( layout.unknownColour ) )
		end
	end

	endingsScreen.isVisible = true
	hintText.isVisible = false
	hintBackground.isVisible = false
end

-- A fresh initStory resets visits, broken links and variables, so every run plays from a clean state.
local function startStory()
	weaver.initStory({
		name = settings.story.name,
		source = settings.story.source,
	})

	endingsScreen.isVisible = false
	hintText.isVisible = true
	hintBackground.isVisible = true
	player:reset()
	player:jumpTo( settings.story.firstPassage )
end

local function onPlayAgainTouch( event )
	if event.phase == "began" then
		startStory()
	end
	return true
end

-- Keeps clicks on the endings screen away from the story underneath.
local function blockTouch()
	return true
end

local function newEndingsScreen( parent )
	local layout = settings.endingsScreen
	local group = display.newGroup()
	parent:insert( group )

	group.backdrop = display.newRect( group, 0, 0, 1, 1 )
	group.backdrop:setFillColor( unpack( layout.backdropColour ) )
	group.backdrop:addEventListener( "touch", blockTouch )

	display.newText( group, layout.title, display.contentCenterX, layout.titleY, settings.font.heading, layout.titleSize )

	for i = 1, #settings.endings do
		local y = layout.listY + ( i - 1 ) * layout.rowSpacing
		endingRows[i] = display.newText( group, layout.unknownTitle, display.contentCenterX, y, settings.font.body, layout.rowSize )
	end

	local button = display.newGroup()
	group:insert( button )
	button.x = display.contentCenterX
	button.y = layout.buttonY

	local buttonBox = display.newRoundedRect( button, 0, 0, layout.buttonWidth, layout.buttonHeight, layout.buttonCornerRadius )
	buttonBox:setFillColor( unpack( layout.buttonColour ) )
	display.newText( button, layout.playAgain, 0, 0, settings.font.heading, layout.buttonTextSize )
	button:addEventListener( "touch", onPlayAgainTouch )

	group.isVisible = false
	return group
end

local function onKey( event )
	if event.phase ~= "down" then
		return false
	end

	if endingsScreen.isVisible then
		if player:isConfirmKey( event.keyName ) then
			startStory()
			return true
		end
		return false
	end

	return player:handleKey( event.keyName )
end

-- The full-screen layers follow the window, as the app's Back button does.
local function fitToScreen()
	player:fitToScreen()
	storyPlayer.coverScreen( endingsScreen.backdrop )
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view

	player = storyPlayer.new({
		parent = sceneGroup,
		storyName = settings.story.name,
		layout = settings.player,
		commands = {
			ending = onEnding,
		},
		onEnd = showEndingsScreen,
	})

	hintBackground = display.newRect( sceneGroup, display.contentCenterX, settings.hint.y, 1, 1 )
	hintBackground:setFillColor( unpack( settings.hint.backgroundColour ) )

	hintText = display.newText( sceneGroup, settings.hint.text, display.contentCenterX, settings.hint.y, settings.font.body, settings.hint.fontSize )
	hintText:setFillColor( unpack( settings.hint.colour ) )

	hintBackground.width = hintText.width + settings.hint.padding * 2
	hintBackground.height = hintText.height + settings.hint.padding * 2

	endingsScreen = newEndingsScreen( sceneGroup )
	fitToScreen()
end

function scene:show( event )
	local phase = event.phase

	if phase == "will" then
		foundEndings = loadFoundEndings()
		startStory()

	elseif phase == "did" then
		Runtime:addEventListener( "key", onKey )
		Runtime:addEventListener( "resize", fitToScreen )
		fitToScreen()
	end
end

function scene:hide( event )
	local phase = event.phase

	-- The key listener goes in hide will, so no key can move the story on during the fade out.
	if phase == "will" then
		Runtime:removeEventListener( "key", onKey )

	elseif phase == "did" then
		Runtime:removeEventListener( "resize", fitToScreen )
	end
end

function scene:destroy()
	weaver.removeFromCache( settings.story.name )

	player:destroy()
	player = nil
	hintText = nil
	hintBackground = nil
	endingsScreen = nil
	endingRows = {}
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
