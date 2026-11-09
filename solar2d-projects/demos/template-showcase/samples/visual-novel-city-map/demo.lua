-- One day on the city map: trips and conversations cost hours, and what people say depends on the time and on what the detective knows.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local weaver = require( "samples.visual-novel-city-map.libs.spyricStoryWeaver" )
local storyPlayer = require( "samples.visual-novel-city-map.classes.storyPlayer" )
local cityMap = require( "samples.visual-novel-city-map.classes.cityMap" )
local dayClock = require( "samples.visual-novel-city-map.classes.dayClock" )
local button = require( "samples.visual-novel-city-map.classes.button" )
local settings = require( "samples.visual-novel-city-map.data.settings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local player
local map
local clock
local hintText
local hintBackground
local playAgainButton

-- The id of the spot the detective is at, from settings.map.spots.
local location
local isEnding = false

--------------------------------------------------------------------------------------
-- Functions

local function setHint( text )
	hintText.text = text or ""
	hintText.isVisible = text ~= nil

	hintBackground.isVisible = hintText.isVisible
	hintBackground.width = hintText.width + settings.hint.padding * 2
	hintBackground.height = hintText.height + settings.hint.padding * 2
end

-- Weaver has no setter, so the time reaches the story through its saved variables, which hold every $ variable.
local function setStoryTime()
	local variables = _G["WEAVERx" .. settings.story.name].saveData
	variables.hour = clock.hour
	variables.band = clock:getBand().id
end

local function playPassage( passageName )
	setStoryTime()
	setHint( settings.hint.story )
	player:jumpTo( passageName )
end

-- The knowledge flags were set by the story itself, so the Ending passage picks the ending on its own.
local function playEnding()
	isEnding = true
	location = settings.time.endLocation

	-- Idea: save the flags with the template's save system here and start the next day with what the detective learned.
	playPassage( settings.story.endingPassage )
end

-- Clicking the spot the detective is already at starts its conversation without a trip.
local function onSpotPick( spot )
	map:close()

	if spot.id ~= location then
		-- Idea: now and then play a random encounter passage here before the detective arrives.
		clock:advance( settings.time.travelHours )
		location = spot.id
	end

	if clock:isOver() then
		playEnding()
	else
		playPassage( spot.passage )
	end
end

-- Handler for <<talk>>, which every conversation runs first; a locked door or an empty street costs no time.
local function onTalk()
	clock:advance( settings.time.talkHours )
	return false
end

local function openMap()
	player:reset()
	map:open( location )
	setHint( settings.hint.map )
end

local function onStoryEnd()
	if isEnding then
		playAgainButton.isVisible = true
		setHint( nil )

	elseif clock:isOver() then
		playEnding()

	else
		openMap()
	end
end

-- A fresh initStory resets the knowledge flags, and the clock starts over with it.
local function startStory()
	weaver.initStory({
		name = settings.story.name,
		source = settings.story.source,
	})

	clock:reset()
	location = settings.time.startLocation
	isEnding = false

	map:close()
	playAgainButton.isVisible = false

	player:reset()
	playPassage( settings.story.firstPassage )
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

local function fitToScreen()
	player:fitToScreen()
	clock:position()
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
			talk = onTalk,
		},
		onEnd = onStoryEnd,
	})

	-- The map belongs to the scenery, so characters always stand in front of it.
	map = cityMap.new({
		parent = player.characterLayer,
		layout = settings.map,
		area = settings.player.background,
		font = settings.font.heading,
		onPick = onSpotPick,
	})

	clock = dayClock.new({
		parent = sceneGroup,
		time = settings.time,
		layout = settings.clock,
		font = settings.font.heading,
	})

	hintBackground = display.newRect( sceneGroup, display.contentCenterX, settings.hint.y, 1, 1 )
	hintBackground:setFillColor( unpack( settings.hint.backgroundColour ) )
	hintBackground.isVisible = false

	hintText = display.newText( sceneGroup, "", display.contentCenterX, settings.hint.y, settings.font.body, settings.hint.fontSize )
	hintText:setFillColor( unpack( settings.hint.colour ) )

	local playAgain = settings.playAgain
	playAgainButton = button.new({
		parent = sceneGroup,
		x = playAgain.x,
		y = playAgain.y,
		width = playAgain.width,
		height = playAgain.height,
		style = settings.buttonStyle,
		isSelected = true,
		label = playAgain.label,
		font = settings.font.heading,
		fontSize = playAgain.fontSize,
		onPress = startStory,
	})

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

	-- During the fade back to the menu the story takes no more keys or clicks, and the map stays drawn but closed.
	if phase == "will" then
		Runtime:removeEventListener( "key", onKey )
		player.isPaused = true
		map.isOpen = false

	elseif phase == "did" then
		Runtime:removeEventListener( "resize", fitToScreen )
	end
end

function scene:destroy()
	weaver.removeFromCache( settings.story.name )

	player:destroy()
	player = nil
	map = nil
	clock = nil
	hintText = nil
	hintBackground = nil
	playAgainButton = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
