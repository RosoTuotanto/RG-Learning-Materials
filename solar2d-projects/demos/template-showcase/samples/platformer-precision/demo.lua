-- A short obstacle course of spikes and wall-jump shafts, with coyote time, jump buffering, wall jumps and a dash.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.platformer-precision.data.settings" )

local camera = require( "samples.platformer-precision.libs.camera" )
local ponytiled = require( "samples.platformer-precision.libs.ponytiled" )

local input = require( "samples.platformer-precision.classes.input" )
local player = require( "samples.platformer-precision.classes.player" )
local course = require( "samples.platformer-precision.classes.course" )
local hud = require( "samples.platformer-precision.classes.hud" )
local sfx = require( "samples.platformer-precision.classes.sfx" )
local volumeSlider = require( "samples.platformer-precision.classes.volumeSlider" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local slider
local sheets = {}
local sounds

local tileSize = settings.sheets.tiles.displaySize

local worldLayer
local world
local map
local hero
local respawnPoint

local overlay

local deathCount = 0
local elapsedTime = 0
local lastFrameTime = 0

local isActive = false
local isComplete = false
local isRestartPending = false
local isRespawnPending = false

--------------------------------------------------------------------------------------
-- Localised functions

local getTimer = system.getTimer

--------------------------------------------------------------------------------------
-- Functions

local function requestRestart()
	isRestartPending = true
end

local function cancelTimersAndTransitions()
	timer.cancel( settings.tag )
	transition.cancel( settings.tag )
end

-- Frames come out at displaySize content units, whatever the pixel size of the image.
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

local function respawnHero()
	isRespawnPending = false

	deathCount = deathCount + 1
	overlay:setDeaths( deathCount )
	sounds:play( "spike" )

	hero:respawn( respawnPoint.x, respawnPoint.y )
	camera.snapToTarget()
end

local function completeCourse()
	-- Idea: save the best time per level with the template's save system and show it here.
	isComplete = true
	hero:stop()
	overlay:showMessage( true )

	timer.performWithDelay( settings.completeDelay, requestRestart, 1, settings.tag )
end

-- Box2D bodies cannot change inside a collision handler, so respawning and finishing wait for the next frame.
local function onHeroCollision( event )
	local other = event.other

	-- Element 1 is the player's solid body; the player handles its own sensors.
	if event.phase ~= "began" or event.selfElement ~= 1 or isComplete then
		return
	end

	if other.kind == "spike" then
		isRespawnPending = true

	elseif other.kind == "checkpoint" and not other.isLit then
		course.lightCheckpoint( other, settings.checkpoint, settings.tag )
		respawnPoint = other.spawn

	elseif other.kind == "flag" then
		isComplete = true
		timer.performWithDelay( 1, completeCourse, 1, settings.tag )
	end
end

-- The camera only scrolls sideways, with the level's bottom edge on the screen's bottom edge.
local function setCameraBounds()
	local halfWidth = display.actualContentWidth * 0.5
	local y = map.designedHeight - display.actualContentHeight * 0.5

	camera.setBounds({ xMin = halfWidth, xMax = map.designedWidth - halfWidth, yMin = y, yMax = y })
end

local function buildWorld()
	world = display.newGroup()
	worldLayer:insert( world )

	-- The map draws the tiles and adds the ground bodies from its "physics" layer; the points on its "game" layer mark where everything else starts.
	-- Idea: add moving platforms and blocks that crumble a moment after the player lands on them.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	course.addSpikes( world, map, tileSize, settings.spike.hurtHeight )
	course.addFlags( world, map, sheets.tiles, settings.checkpoint )

	respawnPoint = map:findObject( "player" )

	hero = player.new({
		parent = world,
		sheet = sheets.characters,
		x = respawnPoint.x,
		y = respawnPoint.y,
		input = controls,
		config = settings.player,
		onMove = function( move ) sounds:play( move ) end,
	})
	hero:addEventListener( "collision", onHeroCollision )

	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( hero, { paddingLeft = settings.camera.padding, paddingRight = settings.camera.padding, smoothing = settings.camera.smoothing } )
	setCameraBounds()
	camera.snapToTarget()

	deathCount = 0
	elapsedTime = 0
	isComplete = false
	isRespawnPending = false

	overlay:showMessage( false )
	overlay:setDeaths( deathCount )
	overlay:setTime( elapsedTime )
end

local function restartCourse()
	isRestartPending = false

	cancelTimersAndTransitions()
	camera.stop()
	display.remove( world )

	buildWorld()
	camera.start()
end

local function onEnterFrame()
	local now = getTimer()
	local frameTime = now - lastFrameTime
	lastFrameTime = now

	if not isActive then
		return
	end

	if isRestartPending then
		restartCourse()
		return
	end

	-- A spike or fall in the same step as the end flag must not count once the course is complete.
	if isRespawnPending and not isComplete then
		respawnHero()
	end

	-- Idea: record the player's position every frame and replay the best run as a see-through ghost.
	if not isComplete then
		hero:update( now )

		elapsedTime = elapsedTime + frameTime
		overlay:setTime( elapsedTime )
	end

	if hero.y > map.designedHeight + settings.fallMargin then
		isRespawnPending = true
	end
end

local function onResize()
	overlay:position()
	slider:reposition()

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

	-- The sheets load their textures here, so every sprite cut from them stays sharp.
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	sheets.tiles = newSheet( settings.sheets.tiles )
	sheets.characters = newSheet( settings.sheets.characters )

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	overlay = hud.new( sceneGroup, settings )

	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })

	sounds = sfx.new( settings.sounds )

	controls = input.new( settings.keys )

	buildWorld()
	onResize()
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		-- Idea: add assist options that slow the game down or give unlimited dashes.
		physics.start()
		physics.setGravity( 0, settings.gravity )

		controls:start()
		camera.start()

		isActive = true
		lastFrameTime = getTimer()
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

		sounds:stopAll()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", onResize )
		slider:stop()
	end
end

function scene:destroy( event )
	sounds:dispose()
	sounds = nil

	controls = nil
	slider = nil
	sheets = {}

	worldLayer = nil
	world = nil
	map = nil
	hero = nil
	respawnPoint = nil

	overlay = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
