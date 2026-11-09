-- Seven days to make rent: two actions a day, and every Weaver choice shows, then applies, what it does to the stats and relationships.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local weaver = require( "samples.visual-novel-life-sim.libs.spyricStoryWeaver" )
local storyPlayer = require( "samples.visual-novel-life-sim.classes.storyPlayer" )
local statsHud = require( "samples.visual-novel-life-sim.classes.statsHud" )
local actionMenu = require( "samples.visual-novel-life-sim.classes.actionMenu" )
local relationshipsPanel = require( "samples.visual-novel-life-sim.classes.relationshipsPanel" )
local effectPreview = require( "samples.visual-novel-life-sim.classes.effectPreview" )
local button = require( "samples.visual-novel-life-sim.classes.button" )
local settings = require( "samples.visual-novel-life-sim.data.settings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local player
local hud
local menu
local panel
local hintText
local hintBackground
local playAgainButton

-- What each passage's <<stat>> and <<relation>> rows change, read once from the story file for the option previews.
local effectsByPassage
local previewParams
local refreshActionPreviews

-- Changed only by the <<stat>> and <<relation>> commands, keyed by the ids in settings.
local stats = {}
local relations = {}

local day = 1
local actionsTaken = 0
local usedActions = {}

--------------------------------------------------------------------------------------
-- Functions

local function clamp( value, range )
	return math.min( math.max( value, range.min ), range.max )
end

local function setHint( text )
	hintText.text = text or ""
	hintText.isVisible = text ~= nil

	hintBackground.isVisible = hintText.isVisible
	hintBackground.width = hintText.width + settings.hint.padding * 2
	hintBackground.height = hintText.height + settings.hint.padding * 2
end

-- Handler for <<stat, id, amount>>; Weaver passes a negative amount as a string.
local function onStat( row )
	local id = row[2]
	local before = stats[id]
	stats[id] = clamp( stats[id] + tonumber( row[3] ), settings.statRange )

	hud:setStat( id, stats[id], true )
	hud:addChange( id, stats[id] - before )
	return false
end

-- Handler for <<relation, id, amount>>.
local function onRelation( row )
	local id = row[2]
	relations[id] = clamp( relations[id] + tonumber( row[3] ), settings.relationRange )

	-- Idea: open a new passage for a character once their value passes a threshold, such as 50.
	return false
end

-- Handler for <<pickAction>> in the Day passage; the line after it stays on screen under the menu.
local function onPickAction()
	refreshActionPreviews()
	menu:open( usedActions )
	setHint( actionsTaken == 0 and settings.hint.actions or settings.hint.lastAction )
	return false
end

-- An option leads to a passage, so the option shows what that passage's rows would change from the current values.
local function addPreview( option, passageName )
	effectPreview.attach( option, effectsByPassage[passageName], { stat = stats, relation = relations }, previewParams )
end

function refreshActionPreviews()
	for i = 1, #settings.actions do
		addPreview( menu.rows[i], settings.actions[i].passage )
	end
end

-- storyPlayer calls this for every choice button it creates.
local function addChoicePreview( choiceButton )
	addPreview( choiceButton, choiceButton.target )
end

local function onActionPicked( index )
	usedActions[index] = true
	menu:close()
	setHint( settings.hint.story )

	-- The changes beside the bars belong to the last choice, and this pick starts the next one.
	hud:clearChanges()

	-- Idea: now and then play a random event from a pool of Weaver passages instead of the chosen action.
	player:jumpTo( settings.actions[index].passage )
end

-- Handler for <<endAction>>, the last row of every choice passage.
local function onEndAction()
	actionsTaken = actionsTaken + 1

	if actionsTaken < settings.calendar.actionsPerDay then
		player:jumpTo( settings.story.dayPassage )
	else
		player:jumpTo( settings.story.dayEndPassage )
	end
end

-- Handler for <<nextDay>> at the end of the DayEnd passage.
local function onNextDay()
	local calendar = settings.calendar

	-- Idea: charge rent every seventh day and keep the calendar running until a payment is missed.
	if day == calendar.days then
		if stats.money < calendar.rent then
			player:jumpTo( settings.story.missedEnding )

		elseif stats.health <= calendar.healthFloor then
			player:jumpTo( settings.story.wornOutEnding )

		else
			player:jumpTo( settings.story.paidEnding )
		end
		return
	end

	day = day + 1
	actionsTaken = 0
	usedActions = {}
	hud:setDay( day, calendar.days )
	player:jumpTo( settings.story.dayPassage )
end

local function onStoryEnd()
	playAgainButton.isVisible = true
	setHint( nil )
end

-- A fresh initStory resets Weaver's visit counts, and the stats start over with it.
local function startStory()
	weaver.initStory({
		name = settings.story.name,
		source = settings.story.source,
	})

	for i = 1, #settings.stats do
		local stat = settings.stats[i]
		stats[stat.id] = stat.start
		hud:setStat( stat.id, stat.start, false )
	end

	hud:clearChanges()

	for i = 1, #settings.relationships do
		local relationship = settings.relationships[i]
		relations[relationship.id] = relationship.start
	end

	day = 1
	actionsTaken = 0
	usedActions = {}
	hud:setDay( day, settings.calendar.days )

	menu:close()
	panel:close()
	playAgainButton.isVisible = false
	setHint( settings.hint.story )

	player:reset()
	player:jumpTo( settings.story.firstPassage )
end

local function onRelationshipsPress()
	panel:open( relations )
end

local function onKey( event )
	if event.phase ~= "down" then
		return false
	end

	local keyName = event.keyName

	if panel:isOpen() then
		return panel:handleKey( keyName )

	elseif playAgainButton.isVisible then
		if player:isConfirmKey( keyName ) then
			startStory()
			return true
		end
		return false

	elseif menu:isOpen() then
		return menu:handleKey( keyName )
	end

	return player:handleKey( keyName )
end

-- The full-screen layers and the stats panel follow the window, as the app's Back button does.
local function fitToScreen()
	player:fitToScreen()
	storyPlayer.coverScreen( menu.blocker )
	storyPlayer.coverScreen( panel.backdrop )
	hud:position()
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view

	effectsByPassage = effectPreview.readStory( settings.story.source, settings.stats, settings.relationships )
	previewParams = {
		layout = settings.effectPreview,
		stats = settings.stats,
		relationships = settings.relationships,
		ranges = { stat = settings.statRange, relation = settings.relationRange },
		imageFolder = settings.imageFolder,
		font = settings.font.heading,
	}

	player = storyPlayer.new({
		parent = sceneGroup,
		storyName = settings.story.name,
		layout = settings.player,
		commands = {
			stat = onStat,
			relation = onRelation,
			pickAction = onPickAction,
			endAction = onEndAction,
			nextDay = onNextDay,
		},
		onEnd = onStoryEnd,
		decorateChoice = addChoicePreview,
	})

	menu = actionMenu.new({
		parent = sceneGroup,
		layout = settings.actionMenu,
		actions = settings.actions,
		font = settings.font,
		style = settings.buttonStyle,
		keys = settings.keys,
		onPick = onActionPicked,
	})

	hud = statsHud.new({
		parent = sceneGroup,
		layout = settings.hud,
		stats = settings.stats,
		range = settings.statRange,
		imageFolder = settings.imageFolder,
		font = settings.font,
		style = settings.buttonStyle,
		onRelationships = onRelationshipsPress,
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

	panel = relationshipsPanel.new({
		parent = sceneGroup,
		layout = settings.relationshipsPanel,
		relationships = settings.relationships,
		range = settings.relationRange,
		imageFolder = settings.imageFolder,
		font = settings.font,
		style = settings.buttonStyle,
		keys = settings.keys,
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

	-- The key listener goes first, so no key can start a bar transition during the fade out.
	if phase == "will" then
		Runtime:removeEventListener( "key", onKey )
		transition.cancel( settings.hud.transitionTag )

	elseif phase == "did" then
		Runtime:removeEventListener( "resize", fitToScreen )
	end
end

function scene:destroy()
	weaver.removeFromCache( settings.story.name )

	player:destroy()
	player = nil
	hud = nil
	menu = nil
	panel = nil
	hintText = nil
	hintBackground = nil
	playAgainButton = nil
	effectsByPassage = nil
	previewParams = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
