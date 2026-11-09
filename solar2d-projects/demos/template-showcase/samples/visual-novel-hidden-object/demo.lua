-- The office from the story turns into a point-and-click search, and every found clue gets its own line.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local weaver = require( "samples.visual-novel-hidden-object.libs.spyricStoryWeaver" )
local storyPlayer = require( "samples.visual-novel-hidden-object.classes.storyPlayer" )
local clueSearch = require( "samples.visual-novel-hidden-object.classes.clueSearch" )
local settings = require( "samples.visual-novel-hidden-object.data.settings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local player
local search
local hintText
local hintBackground
local counterText
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

local function updateCounter()
	counterText.text = string.format( settings.counter.format, search.foundCount, #settings.search.clues )
	counterText.isVisible = true
end

-- Handler for <<search>>, which ends the opening and every clue's remark.
local function onSearch()
	if search:isComplete() then
		player:jumpTo( settings.story.closingPassage )
		return false
	end

	-- Idea: start a countdown here and play a different closing passage when time runs out.
	search:setActive( true )
	updateCounter()
	setHint( settings.hint.search )
	return true
end

-- The found clue reaches the story by its passage, which shares the clue's id.
local function onClueFound( clue )
	-- Idea: save the ids of found clues with the template's save system so the search continues after a restart.
	updateCounter()
	search:setActive( false )
	setHint( settings.hint.story )
	player:jumpTo( clue.id )
end

local function onStoryEnd()
	playAgainButton.isVisible = true
	setHint( nil )
end

-- A fresh initStory resets Weaver's visit counts, so every run plays from a clean state.
local function startStory()
	weaver.initStory({
		name = settings.story.name,
		source = settings.story.source,
	})

	-- Idea: give each room its own background and clue list, and open the next room once this one is cleared.
	search:reset()
	counterText.isVisible = false
	playAgainButton.isVisible = false
	setHint( settings.hint.story )

	player:reset()
	player:jumpTo( settings.story.firstPassage )
end

local function onPlayAgainTouch( event )
	if event.phase == "began" then
		startStory()
	end
	return true
end

local function newPlayAgainButton( parent )
	local layout = settings.playAgain
	local button = display.newGroup()
	parent:insert( button )
	button.x = layout.x
	button.y = layout.y

	local box = display.newRoundedRect( button, 0, 0, layout.width, layout.height, layout.cornerRadius )
	box:setFillColor( unpack( layout.colour ) )
	display.newText( button, layout.label, 0, 0, settings.font.heading, layout.fontSize )

	button:addEventListener( "touch", onPlayAgainTouch )
	return button
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
			search = onSearch,
		},
		onEnd = onStoryEnd,
	})

	-- Clues and covers belong to the room, so they sit below the characters standing in it.
	search = clueSearch.new({
		parent = sceneGroup,
		roomParent = player.characterLayer,
		layout = settings.search,
		strip = settings.strip,
		background = settings.player.background,
		onFound = onClueFound,
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

	playAgainButton = newPlayAgainButton( sceneGroup )
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
		transition.cancel( settings.search.transitionTag )

	elseif phase == "did" then
		Runtime:removeEventListener( "resize", fitToScreen )
	end
end

function scene:destroy()
	weaver.removeFromCache( settings.story.name )

	player:destroy()
	player = nil
	search = nil
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
