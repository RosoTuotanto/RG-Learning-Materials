-- A side-scrolling level with walkers to stomp, coins, coin blocks and a goal flag.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.platformer-classic.data.settings" )

local camera = require( "samples.platformer-classic.libs.camera" )
local ponytiled = require( "samples.platformer-classic.libs.ponytiled" )

local input = require( "samples.platformer-classic.classes.input" )
local player = require( "samples.platformer-classic.classes.player" )
local enemy = require( "samples.platformer-classic.classes.enemy" )
local block = require( "samples.platformer-classic.classes.block" )
local coin = require( "samples.platformer-classic.classes.coin" )
local hud = require( "samples.platformer-classic.classes.hud" )
local sfx = require( "samples.platformer-classic.classes.sfx" )
local volumeSlider = require( "samples.platformer-classic.classes.volumeSlider" )

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
local tileGrid
local hero
local enemies = {}

local overlay

local coinCount = 0
local isActive = false
local isComplete = false
local isRestartPending = false

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor

--------------------------------------------------------------------------------------
-- Functions

-- Box2D bodies cannot change inside a collision handler, so contact results run a frame later.
local function defer( action )
	timer.performWithDelay( 1, action, 1, settings.tag )
end

-- Every tile on the map's "level" layer is ground; positions outside the map are never solid.
local function isSolidAt( x, y )
	local row = tileGrid[floor( y / tileSize ) + 1]
	local gid = row and row[floor( x / tileSize ) + 1]

	return gid ~= nil and gid ~= 0
end

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

local function updateHud()
	overlay:setHearts( hero.hearts )
	overlay:setCoins( coinCount )
end

local function addCoin()
	coinCount = coinCount + 1
	sounds:play( "coin" )
	updateHud()
end

local function stompEnemy( walker )
	enemies[walker] = nil
	walker:squash()
	hero:bounce()
	sounds:play( "stomp" )
end

local function hurtHero( fromX )
	if hero:hurt( fromX ) then
		sounds:play( "hurt" )
		updateHud()

		if hero.hearts <= 0 then
			requestRestart()
		end
	end
end

local function bumpBlock( box )
	if box:bump() then
		coin.release({ parent = world, sheet = sheets.tiles, x = box.x, y = box:getTopY() - tileSize * 0.5, tag = settings.tag, config = settings.coin })
		addCoin()
	end
end

local function completeLevel()
	-- Idea: save the best coin count with the template's save system here.
	isComplete = true
	hero:stop()
	overlay:showMessage( true )

	timer.performWithDelay( settings.completeDelay, requestRestart, 1, settings.tag )
end

local function onHeroCollision( event )
	local other = event.other

	-- Element 1 is the player's solid body; the player handles its own foot sensor.
	if event.phase ~= "began" or event.selfElement ~= 1 or isComplete or other.isHandled then
		return
	end

	if other.kind == "enemy" then
		if hero:getFeetY() <= other:getTopY() + settings.enemy.stompTolerance then
			other.isHandled = true
			defer( function() stompEnemy( other ) end )
		else
			defer( function() hurtHero( other.x ) end )
		end

	elseif other.kind == "coin" then
		other.isHandled = true
		defer( function()
			other:collect()
			addCoin()
		end )

	elseif other.kind == "block" then
		-- Bodies touching side by side do not overlap horizontally, so a graze on the block's corner is not a bump.
		local reach = ( tileSize + settings.player.body.width ) * 0.5 - settings.player.body.chamfer
		local isUnder = math.abs( hero.x - other.x ) < reach

		if isUnder and hero:getHeadY() >= other:getBottomY() - settings.block.headTolerance then
			defer( function() bumpBlock( other ) end )
		end

	elseif other.kind == "flag" then
		other.isHandled = true
		defer( completeLevel )
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
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )
	tileGrid = map:getLayerGrid( "level" )

	local start = map:findObject( "player" )
	hero = player.new({
		parent = world,
		sheet = sheets.characters,
		x = start.x,
		y = start.y,
		input = controls,
		config = settings.player,
		onJump = function() sounds:play( "jump" ) end,
	})
	hero:addEventListener( "collision", onHeroCollision )

	enemies = {}
	local spots = map:findObjects( "enemy" )
	for i = 1, #spots do
		local x, y = spots[i].x, spots[i].y
		local walker = enemy.new({
			parent = world,
			standingSheet = sheets.walker,
			squashedSheet = sheets.walkerSquashed,
			x = x,
			y = y,
			isSolidAt = isSolidAt,
			tag = settings.tag,
			config = settings.enemy,
		})
		enemies[walker] = true
	end

	spots = map:findObjects( "block" )
	for i = 1, #spots do
		local x, y = spots[i].x, spots[i].y
		block.new({ parent = world, sheet = sheets.characters, x = x, y = y, size = tileSize, tag = settings.tag, config = settings.block })
	end

	spots = map:findObjects( "coin" )
	for i = 1, #spots do
		coin.new({ parent = world, sheet = sheets.tiles, x = spots[i].x, y = spots[i].y, tag = settings.tag, config = settings.coin })
	end

	local goal = map:findObject( "flag" )
	local flag = display.newSprite( world, sheets.tiles, settings.flag.sequence )
	flag.x, flag.y = goal.x, goal.y
	flag.kind = "flag"
	flag:play()
	physics.addBody( flag, "static", { isSensor = true } )

	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( hero, { paddingLeft = settings.camera.padding, paddingRight = settings.camera.padding, smoothing = settings.camera.smoothing } )
	setCameraBounds()
	camera.snapToTarget()

	coinCount = 0
	isComplete = false
	overlay:showMessage( false )
	updateHud()
end

local function restartLevel()
	isRestartPending = false

	cancelTimersAndTransitions()
	camera.stop()
	display.remove( world )

	buildWorld()
	camera.start()
end

local function onEnterFrame()
	if not isActive then
		return
	end

	if isRestartPending then
		restartLevel()
		return
	end

	if not isComplete then
		hero:update()
	end

	for walker in pairs( enemies ) do
		walker:update()
	end

	if hero.y > map.designedHeight + settings.fallMargin then
		requestRestart()
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
	sheets.walker = newSheet( settings.sheets.walker )
	sheets.walkerSquashed = newSheet( settings.sheets.walkerSquashed )

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	overlay = hud.new( sceneGroup, sheets.tiles, settings )

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
	tileGrid = nil
	hero = nil
	enemies = {}

	overlay = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
