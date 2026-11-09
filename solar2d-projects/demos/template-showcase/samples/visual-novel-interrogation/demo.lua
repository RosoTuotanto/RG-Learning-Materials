-- Vivian Ash's testimony, broken statement by statement by pressing her and presenting the evidence that proves her wrong.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local weaver = require( "samples.visual-novel-interrogation.libs.spyricStoryWeaver" )
local storyPlayer = require( "samples.visual-novel-interrogation.classes.storyPlayer" )
local evidencePanel = require( "samples.visual-novel-interrogation.classes.evidencePanel" )
local testimonyBar = require( "samples.visual-novel-interrogation.classes.testimonyBar" )
local button = require( "samples.visual-novel-interrogation.classes.button" )
local settings = require( "samples.visual-novel-interrogation.data.settings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local player
local bar
local panel
local hintText
local hintBackground
local endButton

local statementIndex = 1
local isTestimony = false

local isBroken = {}
local foundCount = 0

--------------------------------------------------------------------------------------
-- Functions

local function setHint( text )
	hintText.text = text or ""
	hintText.isVisible = text ~= nil

	hintBackground.isVisible = hintText.isVisible
	hintBackground.width = hintText.width + settings.hint.padding * 2
	hintBackground.height = hintText.height + settings.hint.padding * 2
end

local function setTestimony( isActive )
	isTestimony = isActive
	bar:setVisible( isActive )
	setHint( isActive and settings.hint.testimony or settings.hint.story )
end

local function showStatement( index )
	statementIndex = index
	panel:hidePresented()
	player:jumpTo( settings.statements[index].passage )
	bar:setStatement( index, #settings.statements )
	setTestimony( true )

	-- Idea: start a countdown here that ends the interrogation when the player waits too long on a statement.
end

-- The next statement in the step's direction that is not broken yet; broken statements drop out of the testimony.
local function nextOpenStatement( step )
	local count = #settings.statements
	local index = statementIndex

	for _ = 1, count do
		index = ( index - 1 + step ) % count + 1
		if not isBroken[index] then
			return index
		end
	end
	return statementIndex
end

-- Handler for <<startTestimony>> at the end of the opening.
local function startTestimony()
	-- Idea: give more suspects their own statements table and let the player pick who to question next.
	isBroken = {}
	foundCount = 0
	bar:setFound( foundCount )
	bar:setMarksVisible( true )
	showStatement( 1 )
end

local function runExchange( passageName )
	setTestimony( false )
	player:jumpTo( passageName )
end

-- Handler for <<resumeTestimony>> after every press and presentation.
local function resumeTestimony()
	if foundCount == #settings.statements then
		panel:hidePresented()
		runExchange( settings.story.breakthrough )

	elseif isBroken[statementIndex] then
		showStatement( nextOpenStatement( 1 ) )

	else
		showStatement( statementIndex )
	end
end

local function moveStatement( step )
	showStatement( nextOpenStatement( step ) )
end

-- A wrong clue only plays the statement's nudge toward the right one; nothing is lost.
local function presentClue( clueIndex )
	local clue = settings.clues[clueIndex]
	local statement = settings.statements[statementIndex]
	panel:close()
	panel:showPresented( clueIndex )

	if clue.id == statement.brokenBy then
		isBroken[statementIndex] = true
		foundCount = foundCount + 1
		bar:setFound( foundCount, true )
		runExchange( statement.broken )
	else
		runExchange( statement.wrong )
	end
end

local actions = {
	previous = function()
		moveStatement( -1 )
	end,

	next = function()
		moveStatement( 1 )
	end,

	press = function()
		runExchange( settings.statements[statementIndex].press )
	end,

	-- Idea: list only the clues the player has found, loaded with the template's save system.
	present = function()
		panel:open()
	end,
}

-- A fresh initStory resets Weaver's visit counts, so every run plays from a clean state.
local function startStory()
	weaver.initStory({
		name = settings.story.name,
		source = settings.story.source,
	})

	panel:close()
	endButton.isVisible = false
	panel:hidePresented()
	bar:setMarksVisible( false )
	setTestimony( false )

	player:reset()
	player:jumpTo( settings.story.firstPassage )
end

local function onStoryEnd()
	endButton.isVisible = true
	setHint( nil )
end

local function onEndButtonPress()
	endButton.isVisible = false
	startStory()
end

local function onKey( event )
	if event.phase ~= "down" then
		return false
	end

	local keyName = event.keyName

	if endButton.isVisible then
		if player:isConfirmKey( keyName ) then
			onEndButtonPress()
			return true
		end
		return false

	elseif panel:isOpen() then
		return panel:handleKey( keyName )

	elseif isTestimony then
		for action, keys in pairs( settings.keys ) do
			if actions[action] and storyPlayer.isKeyIn( keyName, keys ) then
				actions[action]()
				return true
			end
		end
		return false
	end

	return player:handleKey( keyName )
end

-- The full-screen layers and the contradiction marks follow the window, as the app's Back button does.
local function fitToScreen()
	player:fitToScreen()
	storyPlayer.coverScreen( bar.blocker )
	storyPlayer.coverScreen( panel.backdrop )
	bar:positionMarks()
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
			startTestimony = startTestimony,
			resumeTestimony = resumeTestimony,
		},
		onEnd = onStoryEnd,
	})

	bar = testimonyBar.new({
		parent = sceneGroup,
		layout = settings.testimony,
		marks = settings.contradictions,
		markCount = #settings.statements,
		font = settings.font,
		style = settings.buttonStyle,
		actions = actions,
	})

	hintBackground = display.newRect( sceneGroup, display.contentCenterX, settings.hint.y, 1, 1 )
	hintBackground:setFillColor( unpack( settings.hint.backgroundColour ) )
	hintBackground.isVisible = false

	hintText = display.newText( sceneGroup, "", display.contentCenterX, settings.hint.y, settings.font.body, settings.hint.fontSize )
	hintText:setFillColor( unpack( settings.hint.colour ) )

	local endLayout = settings.endButton
	endButton = button.new({
		parent = sceneGroup,
		x = endLayout.x,
		y = endLayout.y,
		width = endLayout.width,
		height = endLayout.height,
		style = settings.buttonStyle,
		isSelected = true,
		label = endLayout.label,
		font = settings.font.heading,
		fontSize = endLayout.fontSize,
		onPress = onEndButtonPress,
	})

	panel = evidencePanel.new({
		parent = sceneGroup,
		layout = settings.evidencePanel,
		presented = settings.presentedClue,
		clues = settings.clues,
		clueFolder = settings.clueFolder,
		font = settings.font,
		style = settings.buttonStyle,
		keys = settings.panelKeys,
		onPick = presentClue,
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

	-- The key listener goes in hide will, so no key can move the story on during the fade out.
	if phase == "will" then
		Runtime:removeEventListener( "key", onKey )
		transition.cancel( settings.contradictions.transitionTag )

	elseif phase == "did" then
		Runtime:removeEventListener( "resize", fitToScreen )
	end
end

function scene:destroy()
	weaver.removeFromCache( settings.story.name )

	player:destroy()
	player = nil
	bar = nil
	panel = nil
	hintText = nil
	hintBackground = nil
	endButton = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
