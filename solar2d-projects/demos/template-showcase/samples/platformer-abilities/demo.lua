-- Four rooms, one screen each, where a ledge and a gap stay out of reach until the double jump and the dash are picked up.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.platformer-abilities.data.settings" )

local camera = require( "samples.platformer-abilities.libs.camera" )
local ponytiled = require( "samples.platformer-abilities.libs.ponytiled" )

local input = require( "samples.platformer-abilities.classes.input" )
local rooms = require( "samples.platformer-abilities.classes.rooms" )
local player = require( "samples.platformer-abilities.classes.player" )
local pickups = require( "samples.platformer-abilities.classes.pickups" )
local hud = require( "samples.platformer-abilities.classes.hud" )
local sfx = require( "samples.platformer-abilities.classes.sfx" )
local volumeSlider = require( "samples.platformer-abilities.classes.volumeSlider" )

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
local roomMap
local roomIndex
local hero

local overlay

local isActive = false
local isComplete = false
local isRestartPending = false
local isRespawnPending = false

local onEnterFrame

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

-- The camera holds still on the room's centre, so it glides there whenever the player crosses into another room.
local function enterRoom( index )
	-- Idea: mark each visited room on a map screen that opens with M.
	roomIndex = index
	camera.setBounds( roomMap:boundsOf( index ) )
end

local function respawnHero()
	isRespawnPending = false

	local entry = roomMap.entries[roomIndex]
	hero:respawn( entry.x, entry.y )
end

local function collect( pickup )
	local ability = settings.abilities[pickup.ability]

	transition.cancel( pickup )
	display.remove( pickup )

	-- Idea: save the owned abilities with the template's save system, so they stay after the game closes.
	hero:grant( pickup.ability )
	overlay:light( pickup.ability )
	overlay:showMessage( ability.message )
	sounds:play( "pickup" )
end

local function completeLevel()
	hero:stop()
	overlay:showMessage( settings.text.complete, true )

	timer.performWithDelay( settings.completeDelay, requestRestart, 1, settings.tag )
end

-- Box2D bodies cannot change inside a collision handler, so collecting and finishing wait for the next frame.
local function onHeroCollision( event )
	local other = event.other

	-- Element 1 is the player's solid body; the player handles its own foot sensor.
	if event.phase ~= "began" or event.selfElement ~= 1 or isComplete then
		return
	end

	if other.kind == "pickup" and not other.isTaken then
		other.isTaken = true
		timer.performWithDelay( 1, function() collect( other ) end, 1, settings.tag )

	elseif other.kind == "goal" then
		isComplete = true
		timer.performWithDelay( 1, completeLevel, 1, settings.tag )
	end
end

local function buildWorld()
	world = display.newGroup()
	worldLayer:insert( world )

	-- The map draws the tiles and adds the ground bodies from its "physics" layer; the points on its "game" layer mark
	-- each room's entry, the pickups and the flag.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	roomMap = rooms.new( mapData, settings.roomMargin )
	roomMap:setEntries( map:findObjects( "entry" ) )

	pickups.addAbilities( world, map, settings )
	pickups.addGoal( world, map, sheets.tiles, settings.goal )

	local start = roomMap.entries[1]

	hero = player.new({
		parent = world,
		sheet = sheets.characters,
		x = start.x,
		y = start.y,
		input = controls,
		config = settings.player,
		onMove = function( move ) sounds:play( move ) end,
	})
	hero:addEventListener( "collision", onHeroCollision )

	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( hero, { smoothing = settings.camera.smoothing, maxDistance = settings.camera.maxDistance } )
	enterRoom( roomMap:indexAt( hero.x, hero.y ) )
	camera.snapToTarget()

	isComplete = false
	isRespawnPending = false

	overlay:dimAll()
	overlay:hideMessage()
end

-- camera.start snaps to the room before the first frame update runs.
local function startFrameUpdates()
	camera.start()
	Runtime:addEventListener( "enterFrame", onEnterFrame )
end

local function stopFrameUpdates()
	Runtime:removeEventListener( "enterFrame", onEnterFrame )
	camera.stop()
end

local function restartLevel()
	isRestartPending = false

	cancelTimersAndTransitions()
	stopFrameUpdates()
	display.remove( world )

	buildWorld()
	startFrameUpdates()
end

function onEnterFrame()
	if not isActive then
		return
	end

	if isRestartPending then
		restartLevel()
		return
	end

	if isRespawnPending and not isComplete then
		respawnHero()
	end

	if not isComplete then
		hero:update( getTimer() )
	end

	local index = roomMap:indexFrom( roomIndex, hero.x, hero.y )
	if index ~= roomIndex then
		enterRoom( index )
	end

	if hero.y > map.designedHeight + settings.fallMargin then
		isRespawnPending = true
	end
end

local function onResize()
	overlay:position()
	slider:reposition()
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

	overlay = hud.new( sceneGroup, settings, tileSize )

	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })

	sounds = sfx.new( settings.sounds )

	controls = input.new( settings.keys )

	buildWorld()
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, settings.gravity )

		controls:start()

		isActive = true
		startFrameUpdates()
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
		stopFrameUpdates()
		cancelTimersAndTransitions()

		sounds:stopAll()

	elseif phase == "did" then
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
	roomMap = nil
	hero = nil

	overlay = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
