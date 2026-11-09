-- Top-down racing on a looped Tiled track larger than the screen; the car, the map and the finish line live in the group the camera moves.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.top-down-racing.data.settings" )

local camera = require( "samples.top-down-racing.libs.camera" )
local ponytiled = require( "samples.top-down-racing.libs.ponytiled" )

local car = require( "samples.top-down-racing.classes.car" )
local checkpoints = require( "samples.top-down-racing.classes.checkpoints" )
local hud = require( "samples.top-down-racing.classes.hud" )
local input = require( "samples.top-down-racing.classes.input" )
local laps = require( "samples.top-down-racing.classes.laps" )
local mapGrid = require( "samples.top-down-racing.classes.mapGrid" )
local sfx = require( "samples.top-down-racing.classes.sfx" )
local volumeSlider = require( "samples.top-down-racing.classes.volumeSlider" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local world
local grid
local racer
local tracker

local controls
local overlay
local slider
local sounds

-- system.getTimer() value of the last bump sound, so a crash that touches two tiles at once plays it once.
local lastBumpTime = 0

local lastFrameTime = nil
local isActive = false

--------------------------------------------------------------------------------------
-- Localised functions

local min = math.min

--------------------------------------------------------------------------------------
-- Functions

-- The collision listener only updates lap state, the HUD and sound, so no body changes need deferring here.
-- Sounds play only with something the player sees: the lap times lighting up, or the car hitting a tree or rock.
local function onCarCollision( event )
	if event.phase ~= "began" then
		return
	end

	local other = event.other

	if other.checkpointIndex then
		tracker:crossCheckpoint( other.checkpointIndex )

	elseif other.isFinish then
		local result = tracker:crossFinish()

		if result == "lap" or result == "best" then
			-- Idea: record the car's position every frame and replay the best lap as a see-through ghost car.
			sounds:play( "lap" )
			overlay:highlightLap( result == "best" )

		elseif result == "missed" then
			overlay:showMessage( settings.text.missed )
		end

	else
		local now = system.getTimer()

		if racer:getSpeedInto( other, grid ) >= settings.bumpSpeed and now - lastBumpTime >= settings.bumpCooldown then
			lastBumpTime = now
			sounds:play( "bump" )
		end
	end
end

-- The camera stops at the world's edges, so the area outside the track never shows.
local function setCameraBounds()
	local halfWidth = display.actualContentWidth * 0.5
	local halfHeight = display.actualContentHeight * 0.5

	camera.setBounds({ xMin = halfWidth, xMax = grid.width - halfWidth, yMin = halfHeight, yMax = grid.height - halfHeight })
end

local function buildWorld( parent )
	world = display.newGroup()
	parent:insert( world )

	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	-- The map draws the track and adds the tree and rock bodies from its "physics" layer; its hidden "game" layer holds
	-- the start, the checkpoint rects in order and the finish rect.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	local map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	grid = mapGrid.new( map, mapData )

	-- Idea: add power-ups as objects on the map's game layer, such as a boost pad that pushes the car forward.
	local checkpointCount = checkpoints.new( world, map, settings.finishLine )

	local start = map:findObject( "start" )
	racer = car.new({
		parent = world,
		x = start.x,
		y = start.y,
		controls = controls,
		config = settings.car,
		pixelsPerMeter = settings.pixelsPerMeter,
	})
	racer:addEventListener( "collision", onCarCollision )

	-- Idea: add AI opponents that drive the same car class toward a list of waypoints around the track.

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	tracker = laps.new( checkpointCount )

	local padding = settings.camera.padding
	camera.init({ { group = world, delta = 1 } })
	camera.setTarget( racer, { paddingLeft = padding, paddingRight = padding, paddingUp = padding, paddingDown = padding, smoothing = settings.camera.smoothing } )
	setCameraBounds()
	camera.snapToTarget()
end

local function onEnterFrame( event )
	if not isActive then
		return
	end

	local deltaTime = min( event.time - ( lastFrameTime or event.time ), settings.maxFrameTime )
	lastFrameTime = event.time

	-- The car is a child of the world group, so its x and y are already world coordinates however far the camera has moved.
	racer:drive( grid:isTrackAt( racer.x, racer.y ) )

	tracker:update( deltaTime / 1000 )
	overlay:setTimes( tracker.current, tracker.last, tracker.best )
	overlay:update( deltaTime )
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

	local worldLayer = display.newGroup()
	sceneGroup:insert( worldLayer )

	overlay = hud.new( sceneGroup, settings )
	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })
	sounds = sfx.new( settings.sounds )
	controls = input.new( settings.keys )

	buildWorld( worldLayer )
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, 0 )

		controls:start()
		camera.start()

		lastFrameTime = nil
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

		-- Releasing every key now keeps the car still while the scene fades out.
		controls:stop()
		camera.stop()

		sounds:stopAll()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", onResize )
		slider:stop()
	end
end

function scene:destroy( event )
	racer:removeEventListener( "collision", onCarCollision )

	sounds:dispose()
	sounds = nil

	controls = nil
	overlay = nil
	slider = nil

	world = nil
	grid = nil
	racer = nil
	tracker = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
