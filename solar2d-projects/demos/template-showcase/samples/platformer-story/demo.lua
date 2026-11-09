-- A village platformer where talking to the villagers through a Weaver story lowers the bridge to the level's end.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.platformer-story.data.settings" )

local camera = require( "samples.platformer-story.libs.camera" )
local ponytiled = require( "samples.platformer-story.libs.ponytiled" )
local weaver = require( "samples.platformer-story.libs.spyricStoryWeaver" )

local input = require( "samples.platformer-story.classes.input" )
local player = require( "samples.platformer-story.classes.player" )
local villagers = require( "samples.platformer-story.classes.villagers" )
local bridge = require( "samples.platformer-story.classes.bridge" )
local dialogueBox = require( "samples.platformer-story.classes.dialogueBox" )
local hud = require( "samples.platformer-story.classes.hud" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local sheets = {}

local tileSize = settings.sheets.tiles.displaySize
local characterSize = settings.sheets.characters.displaySize

local worldLayer
local world
local map
local hero
local crowd
local drawbridge
local respawnPoint

local dialogue
local overlay

local isActive = false
local isTalking = false
local isComplete = false
local isRestartPending = false

--------------------------------------------------------------------------------------
-- Functions

local function requestRestart()
	isRestartPending = true
end

local function cancelTimersAndTransitions()
	timer.cancel( settings.tag )
	transition.cancel( settings.tag )
end

-- Pixel art keeps hard edges only when its texture loads under the nearest filter.
local function setTextureFilter( filter )
	display.setDefault( "magTextureFilter", filter )
	display.setDefault( "minTextureFilter", filter )
end

local function newSheet( config )
	local size = config.displaySize

	return graphics.newImageSheet( config.path, {
		width = size,
		height = size,
		numFrames = config.columns * config.rows,
		sheetContentWidth = config.columns * size,
		sheetContentHeight = config.rows * size,
	} )
end

-- Custom commands the story runs, as <<name, arguments>> rows.
local storyCommands = {
	lowerBridge = function()
		drawbridge:lower()
	end,
}

local function completeLevel()
	-- Idea: save the story's variables with the template's save system here, so the village remembers the player's choices.
	isComplete = true
	hero:stop()
	overlay:showMessage( true )

	timer.performWithDelay( settings.completeDelay, requestRestart, 1, settings.tag )
end

local function onHeroCollision( event )
	-- Element 1 is the player's solid body; the player handles its own foot sensor.
	if event.phase == "began" and event.selfElement == 1 and event.other.kind == "flag" and not isComplete then
		completeLevel()
	end
end

-- The camera only scrolls sideways, with the level's bottom edge on the screen's bottom edge.
local function setCameraBounds()
	local halfWidth = display.actualContentWidth * 0.5
	local y = map.designedHeight - display.actualContentHeight * 0.5

	camera.setBounds({ xMin = halfWidth, xMax = map.designedWidth - halfWidth, yMin = y, yMax = y })
end

local function buildWorld()
	-- A fresh initStory resets every story variable, so each visit to the village starts from the beginning.
	weaver.initStory({ name = settings.story.name, source = settings.story.source })

	world = display.newGroup()
	worldLayer:insert( world )

	setTextureFilter( "nearest" )

	-- The map draws the tiles and adds the ground bodies from its "physics" layer; its "game" layer marks where everything else goes.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	map:findObject( "river" ):setFillColor( unpack( settings.colors.water ) )

	drawbridge = bridge.new({ parent = world, area = map:findObject( "bridge" ), size = tileSize, tag = settings.tag, config = settings.bridge })

	-- Idea: give the villagers daily schedules that move them around the village, with a Weaver variable for the time of day.
	crowd = villagers.new({
		parent = world,
		map = map,
		size = characterSize,
		list = settings.villagers,
		config = settings.talk,
		colors = settings.colors,
		font = settings.font.heading,
		promptText = settings.text.talk,
	})

	local goal = map:findObject( "flag" )
	local flag = display.newSprite( world, sheets.tiles, settings.flag.sequence )
	flag.x, flag.y = goal.x, goal.y
	flag.kind = "flag"
	flag:play()
	physics.addBody( flag, "static", { isSensor = true } )

	setTextureFilter( "linear" )

	local start = map:findObject( "player" )
	hero = player.new({ parent = world, sheet = sheets.characters, x = start.x, y = start.y, input = controls, config = settings.player })
	hero:addEventListener( "collision", onHeroCollision )

	respawnPoint = map:findObject( "respawn" )

	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( hero, { paddingLeft = settings.camera.padding, paddingRight = settings.camera.padding, smoothing = settings.camera.smoothing } )
	setCameraBounds()
	camera.snapToTarget()

	isComplete = false
	isTalking = false
	overlay:showMessage( false )
	overlay:showHint( true )
end

local function restartLevel()
	isRestartPending = false

	cancelTimersAndTransitions()
	camera.stop()
	display.remove( world )

	buildWorld()
	camera.start()
end

local function updateDialogue()
	dialogue:handleInput( controls )

	-- Keys pressed while talking never reach the player, even the one that closed the dialogue.
	controls:clearPresses()

	if not dialogue:isOpen() then
		isTalking = false
		overlay:showHint( true )
	end
end

-- Opens the dialogue when the talk key is pressed next to a villager; returns true when it did.
local function talkToNearbyVillager()
	local wantsTalk = controls:takePress( "talk" )
	local person = crowd:update( hero )

	if not ( person and wantsTalk ) then
		return false
	end

	-- The talk key may also be the jump key, so its press must not make the player jump as well.
	controls:clearPresses()
	isTalking = true
	hero:stop()
	person.prompt.isVisible = false
	person:face( hero.x < person.x and -1 or 1 )
	overlay:showHint( false )

	-- Idea: track a quest's steps in Weaver variables and list the open ones in a quest log.
	dialogue:open( person.info.passage, person.info.name )
	return true
end

local function onEnterFrame()
	if not isActive then
		return
	end

	if isRestartPending then
		restartLevel()
		return
	end

	if isTalking then
		updateDialogue()
		return
	end

	if isComplete or talkToNearbyVillager() then
		return
	end

	hero:update()

	if hero.y > map.designedHeight + settings.fallMargin then
		hero:respawn( respawnPoint.x, respawnPoint.y )
	end
end

local function onResize()
	overlay:position()
	dialogue:position()
	setCameraBounds()
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view

	-- Bodies can only be added once physics has started; show resumes it.
	physics.start()
	physics.pause()

	-- Oversized so it still covers the screen after the window is resized.
	local sky = display.newRect( sceneGroup, display.contentCenterX, display.contentCenterY, display.actualContentWidth * 4, display.actualContentHeight * 4 )
	sky:setFillColor( unpack( settings.colors.sky ) )

	worldLayer = display.newGroup()
	sceneGroup:insert( worldLayer )

	setTextureFilter( "nearest" )
	sheets.tiles = newSheet( settings.sheets.tiles )
	sheets.characters = newSheet( settings.sheets.characters )
	setTextureFilter( "linear" )

	overlay = hud.new( sceneGroup, settings )

	dialogue = dialogueBox.new({
		parent = sceneGroup,
		storyName = settings.story.name,
		config = settings.dialogue,
		colors = settings.colors,
		font = settings.font,
		commands = storyCommands,
	})

	controls = input.new( settings.keys )

	buildWorld()
	onResize()
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, settings.gravity )

		controls:start()
		camera.start()

		isActive = true
		Runtime:addEventListener( "enterFrame", onEnterFrame )
		Runtime:addEventListener( "resize", onResize )
		onResize()
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		isActive = false
		physics.pause()

		-- Releasing every key now keeps the player still while the scene fades out.
		controls:stop()
		hero:stop()
		camera.stop()
		cancelTimersAndTransitions()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", onResize )
	end
end

function scene:destroy( event )
	weaver.removeFromCache( settings.story.name )

	controls = nil
	sheets = {}

	worldLayer = nil
	world = nil
	map = nil
	hero = nil
	crowd = nil
	drawbridge = nil
	respawnPoint = nil

	dialogue = nil
	overlay = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
