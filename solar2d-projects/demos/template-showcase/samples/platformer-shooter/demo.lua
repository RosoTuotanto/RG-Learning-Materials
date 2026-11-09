-- A side-scrolling level where the gun aims at the mouse cursor and every turret has to be shot down.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.platformer-shooter.data.settings" )

local camera = require( "samples.platformer-shooter.libs.camera" )
local ponytiled = require( "samples.platformer-shooter.libs.ponytiled" )

local pixelArt = require( "samples.platformer-shooter.classes.pixelArt" )
local input = require( "samples.platformer-shooter.classes.input" )
local player = require( "samples.platformer-shooter.classes.player" )
local gun = require( "samples.platformer-shooter.classes.gun" )
local turret = require( "samples.platformer-shooter.classes.turret" )
local bullets = require( "samples.platformer-shooter.classes.bullets" )
local hud = require( "samples.platformer-shooter.classes.hud" )
local sfx = require( "samples.platformer-shooter.classes.sfx" )
local volumeSlider = require( "samples.platformer-shooter.classes.volumeSlider" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local slider
local sheets = {}
local sounds

local worldLayer
local world
local map
local hero
local weapon
local shots
local squad

local overlay

local cursorX = display.contentCenterX
local cursorY = display.contentCenterY
local nextShotAt = 0

local isActive = false
local isOver = false
local isRestartPending = false

local onEnterFrame

--------------------------------------------------------------------------------------
-- Functions

local function requestRestart()
	isRestartPending = true
end

local function cancelTimersAndTransitions()
	timer.cancel( settings.tag )
	transition.cancel( settings.tag )
end

-- The world group moves with the camera, so the same screen point is a different world point from frame to frame.
local function getCursorInWorld()
	return world:contentToLocal( cursorX, cursorY )
end

local function endLevel( messageText )
	isOver = true
	hero:stop()
	overlay:showMessage( messageText )

	timer.performWithDelay( settings.messageTime, requestRestart, 1, settings.tag )
end

local function hurtHero( damage, fromX )
	hero:hurt( damage, fromX )
	sounds:play( "hit" )
	overlay:setHp( hero.hp, settings.player.hp )

	if hero.hp <= 0 then
		endLevel( settings.text.defeated )
	end
end

local function hitTurret( target, damage )
	sounds:play( "hit" )

	squad:hit( target, damage )

	if squad.count == 0 then
		-- Idea: save the cleared area and the time it took with the template's save system here.
		endLevel( settings.text.cleared )
	end
end

-- Bullets report hits a frame after the contact, so turrets can be removed here.
local function onBulletHit( other, damage, x )
	if isOver then
		return
	end

	if other == hero then
		hurtHero( damage, x )

	elseif squad:has( other ) then
		hitTurret( other, damage )
	end
end

local function onTurretFire( x, y, heading )
	shots:fire( "turret", x, y, heading )
	sounds:play( "turretShot" )
end

-- Each axis keeps the view inside the level, or centres the level when the screen is the larger of the two.
local function getAxisBounds( levelSize, screenSize )
	if levelSize <= screenSize then
		return levelSize * 0.5, levelSize * 0.5
	end

	return screenSize * 0.5, levelSize - screenSize * 0.5
end

local function setCameraBounds()
	local xMin, xMax = getAxisBounds( map.designedWidth, display.actualContentWidth )
	local yMin, yMax = getAxisBounds( map.designedHeight, display.actualContentHeight )

	camera.setBounds({ xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax })
end

local function buildWorld()
	world = display.newGroup()
	worldLayer:insert( world )

	pixelArt.setFilter( true )

	-- The map draws the tiles and adds the wall bodies from its "physics" layer; the points on its "game" layer place the player and the turrets.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	squad = turret.newSquad({
		parent = world,
		spots = map:findObjects( "turret" ),
		filter = settings.filters.turret,
		config = settings.turret,
		onFire = onTurretFire,
	})

	local start = map:findObject( "player" )
	hero = player.new({
		parent = world,
		sheet = sheets.characters,
		x = start.x,
		y = start.y,
		input = controls,
		filter = settings.filters.player,
		config = settings.player,
	})

	weapon = gun.new({ parent = world, config = settings.gun })
	pixelArt.setFilter( false )

	shots = bullets.new({ parent = world, config = settings.bullets, filters = settings.filters, tag = settings.tag, onHit = onBulletHit })

	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( hero, settings.camera )
	setCameraBounds()
	camera.snapToTarget()

	isOver = false
	nextShotAt = 0
	overlay:showMessage( nil )
	overlay:setHp( hero.hp, settings.player.hp )
end

-- The camera's frame listener runs before onEnterFrame, so the cursor converts to world space after that frame's camera move.
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

	local aimX, aimY = getCursorInWorld()

	if not isOver then
		hero:update()
		squad:update( hero.x, hero.y )
	end

	weapon:aimAt( hero, aimX, aimY )
	shots:update()
end

local function onMouse( event )
	cursorX, cursorY = event.x, event.y
end

-- The Back button and the volume slider handle their own touches, so pressing them never shoots.
local function onTouch( event )
	if event.phase ~= "began" or not isActive or isOver then
		return false
	end

	cursorX, cursorY = event.x, event.y

	local now = system.getTimer()
	if now < nextShotAt then
		return true
	end

	nextShotAt = now + settings.gun.cooldown

	-- A touch screen has no cursor between touches, so the gun turns to the touch before it fires.
	local aimX, aimY = getCursorInWorld()
	weapon:aimAt( hero, aimX, aimY )

	local tipX, tipY = weapon:getTip()
	shots:fire( "player", tipX, tipY, weapon.heading )
	sounds:play( "shoot" )

	return true
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

	sheets.characters = pixelArt.newSheet( settings.sheets.characters )

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
		physics.start()
		physics.setGravity( 0, settings.gravity )

		controls:start()

		-- Leaving cancelled the timer that would have restarted a finished level.
		if isOver then
			requestRestart()
		end

		isActive = true
		startFrameUpdates()
		Runtime:addEventListener( "mouse", onMouse )
		Runtime:addEventListener( "touch", onTouch )
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
		shots:clear()

		sounds:stopAll()

	elseif phase == "did" then
		Runtime:removeEventListener( "mouse", onMouse )
		Runtime:removeEventListener( "touch", onTouch )
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
	weapon = nil
	shots = nil
	squad = nil

	overlay = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
