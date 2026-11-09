-- The office opening leads to a corkboard, and the clues linked to each suspect decide how the case ends.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local weaver = require( "samples.visual-novel-deduction.libs.spyricStoryWeaver" )
local storyPlayer = require( "samples.visual-novel-deduction.classes.storyPlayer" )
local deductionBoard = require( "samples.visual-novel-deduction.classes.deductionBoard" )
local accusation = require( "samples.visual-novel-deduction.classes.accusation" )
local button = require( "samples.visual-novel-deduction.classes.button" )
local settings = require( "samples.visual-novel-deduction.data.settings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local player
local board
local hintText
local hintBackground
local counterText
local accuseButton
local playAgainButton

--------------------------------------------------------------------------------------
-- Functions

local function setHint( text )
	hintText.text = text or ""
	hintText.isVisible = text ~= nil

	hintBackground.isVisible = hintText.isVisible
	hintBackground.width = hintText.width + settings.hint.padding * 2
	hintBackground.height = hintText.height + settings.hint.padding * 2
end

local function updateCounter( changedBoard )
	counterText.text = string.format( settings.counter.format, changedBoard:getLinkCount() )
end

-- Handler for <<board>>, the last row of the Board passage, so the story goes idle and clicks reach the cards.
local function onBoard()
	-- Idea: start a timer here and jump to a passage where Briggs loses patience when it runs out.
	board:open()
	counterText.isVisible = true
	accuseButton.isVisible = true
	setHint( settings.hint.board )
	return false
end

-- The verdict reaches the story as the passage it jumps to.
local function onAccusePress()
	local verdict = accusation.judge( board:getLinks(), settings.case )

	-- Idea: after a wrong accusation, show a hint and let the player rework the board.
	board:stopLinking()
	counterText.isVisible = false
	accuseButton.isVisible = false
	setHint( settings.hint.story )
	player:jumpTo( settings.story.verdictPassages[verdict] )
end

-- The Board passage ends with the board taking links; only a verdict's end offers a new game.
local function onStoryEnd()
	if not board.isLinking then
		playAgainButton.isVisible = true
		setHint( nil )
	end
end

-- A fresh initStory resets Weaver's visit counts, so every run plays from a clean state.
local function startStory()
	weaver.initStory({
		name = settings.story.name,
		source = settings.story.source,
	})

	board:reset()
	counterText.isVisible = false
	accuseButton.isVisible = false
	playAgainButton.isVisible = false
	setHint( settings.hint.story )

	player:reset()
	player:jumpTo( settings.story.firstPassage )
end

local function newButton( layout, onPress, parent )
	local buttonGroup = button.new({
		parent = parent,
		x = layout.x,
		y = layout.y,
		width = layout.width,
		height = layout.height,
		style = settings.buttonStyle,
		label = layout.label,
		font = settings.font.heading,
		onPress = onPress,
	})

	buttonGroup.isVisible = false
	return buttonGroup
end

local function onKey( event )
	if event.phase ~= "down" then
		return false
	end

	if playAgainButton.isVisible then
		if player:isConfirmKey( event.keyName ) then
			startStory()
			return true
		end
		return false
	end

	return player:handleKey( event.keyName )
end

-- The counter stays under the app's Back button, which follows the window's top-left corner.
local function fitToScreen()
	player:fitToScreen()

	counterText.x = display.screenOriginX + settings.counter.x
	counterText.y = display.screenOriginY + settings.counter.y
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
			board = onBoard,
		},
		onEnd = onStoryEnd,
	})

	-- The cards belong to the room, so the characters in a verdict stand in front of them.
	board = deductionBoard.new({
		parent = player.characterLayer,
		layout = settings.board,
		onChange = updateCounter,
	})

	hintBackground = display.newRect( sceneGroup, display.contentCenterX, settings.hint.y, 1, 1 )
	hintBackground:setFillColor( unpack( settings.hint.backgroundColour ) )
	hintBackground.isVisible = false

	hintText = display.newText( sceneGroup, "", display.contentCenterX, settings.hint.y, settings.font.body, settings.hint.fontSize )
	hintText:setFillColor( unpack( settings.hint.colour ) )

	local counter = settings.counter
	counterText = display.newText( sceneGroup, "", 0, 0, settings.font.heading, counter.fontSize )
	counterText.anchorX = 0
	counterText.anchorY = 0
	counterText:setFillColor( unpack( counter.colour ) )

	accuseButton = newButton( settings.accuse, onAccusePress, sceneGroup )
	playAgainButton = newButton( settings.playAgain, startStory, sceneGroup )
	fitToScreen()
end

function scene:show( event )
	local phase = event.phase

	if phase == "will" then
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
		board:cancelDrag()

	elseif phase == "did" then
		Runtime:removeEventListener( "resize", fitToScreen )
	end
end

function scene:destroy()
	weaver.removeFromCache( settings.story.name )
	board:cancelDrag()

	player:destroy()
	player = nil
	board = nil
	hintText = nil
	hintBackground = nil
	counterText = nil
	playAgainButton = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
