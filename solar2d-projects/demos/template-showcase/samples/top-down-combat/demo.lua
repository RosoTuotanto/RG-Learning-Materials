-- Top-down combat in a world larger than the screen; every fighter and arrow lives in the group the camera moves.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.top-down-combat.data.settings" )

local camera = require( "samples.top-down-combat.libs.camera" )
local ponytiled = require( "samples.top-down-combat.libs.ponytiled" )

local hud = require( "samples.top-down-combat.classes.hud" )
local input = require( "samples.top-down-combat.classes.input" )
local player = require( "samples.top-down-combat.classes.player" )
local projectiles = require( "samples.top-down-combat.classes.projectiles" )
local sfx = require( "samples.top-down-combat.classes.sfx" )
local volumeSlider = require( "samples.top-down-combat.classes.volumeSlider" )
local waves = require( "samples.top-down-combat.classes.waves" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local worldLayer
local world
local map
local hero
local arrows
local spawner

local controls
local overlay
local slider
local sounds

-- The last cursor position in content coordinates; it becomes a world point only when used.
local cursorX = display.contentCenterX
local cursorY = display.contentCenterY

local defeatTimeLeft = 0

local lastFrameTime = nil
local isActive = false

local onEnterFrame

--------------------------------------------------------------------------------------
-- Localised functions

local min = math.min

--------------------------------------------------------------------------------------
-- Functions

-- Enemies and arrows are also created mid-game, so every place that builds sprites switches to pixel-art filtering and back.
local function setPixelArtFilter( isPixelArt )
	local filter = isPixelArt and "nearest" or "linear"

	display.setDefault( "magTextureFilter", filter )
	display.setDefault( "minTextureFilter", filter )
end

local function onEnemyAttack( role )
	if role == "melee" then
		sounds:play( "swing" )
	else
		sounds:play( "shoot" )
	end
end

local function onEnemyHit()
	sounds:play( "hit" )
end

local function onHeroHurt( hp )
	sounds:play( "hurt" )
	overlay:setHp( hp, settings.player.maxHp )

	if hp <= 0 then
		-- Idea: save the best wave reached with the template's save system before the room resets.
		overlay:showMessage( true )
		defeatTimeLeft = settings.defeatTime
	end
end

-- The camera stops at the world's edges, so the area outside the level never shows.
local function setCameraBounds()
	local halfWidth = display.actualContentWidth * 0.5
	local halfHeight = display.actualContentHeight * 0.5

	camera.setBounds({ xMin = halfWidth, xMax = map.designedWidth - halfWidth, yMin = halfHeight, yMax = map.designedHeight - halfHeight })
end

local function buildWorld()
	world = display.newGroup()
	worldLayer:insert( world )

	setPixelArtFilter( true )

	-- The map draws the tiles; its "game" layer marks the hero's start and the enemy spawn points.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	-- The wall rects on the "physics" layer carry no body, because a Tiled property cannot hold the walls' collision filter.
	local walls = map:findLayer( "physics" )
	for i = 1, walls.numChildren do
		physics.addBody( walls[i], "static", { friction = settings.wallBody.friction, filter = settings.filters.wall } )
	end

	local start = map:findObject( "player" )
	hero = player.new({
		parent = world,
		x = start.x,
		y = start.y,
		input = controls,
		filter = settings.filters.hero,
		body = settings.fighterBody,
		config = settings.player,
		reaction = settings.reactions.hero,
		flashColor = settings.colors.hitFlash,
		onHurt = onHeroHurt,
	})

	arrows = projectiles.new({ parent = world, config = settings.arrows, filters = settings.filters, tag = settings.tag })

	spawner = waves.new({
		parent = world,
		spawnPoints = map:findObjects( "spawn" ),
		hero = hero,
		projectiles = arrows,
		settings = settings,
		onWave = function( number ) overlay:setWave( number ) end,
		onAttack = onEnemyAttack,
		onHit = onEnemyHit,
	})

	defeatTimeLeft = 0
	spawner:spawnNext()

	setPixelArtFilter( false )

	local padding = settings.camera.padding
	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( hero, { paddingLeft = padding, paddingRight = padding, paddingUp = padding, paddingDown = padding, smoothing = settings.camera.smoothing } )
	setCameraBounds()
	camera.snapToTarget()

	overlay:setHp( hero.hp, settings.player.maxHp )
	overlay:showMessage( false )
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

local function resetRoom()
	timer.cancel( settings.tag )
	stopFrameUpdates()
	display.remove( world )

	buildWorld()
	startFrameUpdates()
end

-- The world group moves with the camera, so the same screen point is a different world point from frame to frame.
local function getCursorInWorld()
	return world:contentToLocal( cursorX, cursorY )
end

function onEnterFrame( event )
	if not isActive then
		return
	end

	local deltaTime = min( event.time - ( lastFrameTime or event.time ), settings.maxFrameTime )
	lastFrameTime = event.time

	if defeatTimeLeft > 0 then
		defeatTimeLeft = defeatTimeLeft - deltaTime

		if defeatTimeLeft <= 0 then
			resetRoom()
			return
		end
	end

	hero:aimAt( getCursorInWorld() )

	setPixelArtFilter( true )
	hero:update( deltaTime )
	spawner:update( deltaTime )
	arrows:update( deltaTime )
	setPixelArtFilter( false )
end

local function onMouse( event )
	cursorX, cursorY = event.x, event.y
end

-- The back button and the volume slider handle their own touches, so pressing them never shoots.
local function onTouch( event )
	if event.phase ~= "began" or not isActive then
		return false
	end

	cursorX, cursorY = event.x, event.y
	hero:aimAt( getCursorInWorld() )

	if hero:tryShoot() then
		setPixelArtFilter( true )
		arrows:fire( "hero", hero.x, hero.y, hero.aimHeading )
		setPixelArtFilter( false )

		sounds:play( "shoot" )
	end

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

	worldLayer = display.newGroup()
	sceneGroup:insert( worldLayer )

	overlay = hud.new( sceneGroup, settings )
	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })
	sounds = sfx.new( settings.sounds )
	controls = input.new( settings.keys )

	buildWorld()
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, 0 )

		controls:start()

		lastFrameTime = nil
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

		-- Releasing every key now keeps the hero still while the scene fades out.
		controls:stop()
		hero:stop()
		spawner:stopAttacks()
		stopFrameUpdates()
		timer.cancel( settings.tag )

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
	overlay = nil
	slider = nil

	worldLayer = nil
	world = nil
	map = nil
	hero = nil
	arrows = nil
	spawner = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
