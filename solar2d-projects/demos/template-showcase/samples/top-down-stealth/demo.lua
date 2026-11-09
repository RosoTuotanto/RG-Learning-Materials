-- Sneak past patrolling guards to the door; each guard sees along its cone until a wall blocks the line.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local json = require( "json" )
local physics = require( "physics" )

local settings = require( "samples.top-down-stealth.data.settings" )

local ponytiled = require( "samples.top-down-stealth.libs.ponytiled" )
local input = require( "samples.top-down-stealth.classes.input" )
local player = require( "samples.top-down-stealth.classes.player" )
local guard = require( "samples.top-down-stealth.classes.guard" )
local sfx = require( "samples.top-down-stealth.classes.sfx" )
local volumeSlider = require( "samples.top-down-stealth.classes.volumeSlider" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local hero
local guards = {}

local start
local door
local tileSize

local message
local slider
local sounds

local restartTimer
local lastFrameTime = 0

-- "playing", "caught", "escaped" or "paused"; the room only moves while playing.
local state = "paused"

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor
local getTimer = system.getTimer
local min = math.min

--------------------------------------------------------------------------------------
-- Functions

local function restartRoom()
	restartTimer = nil

	hero:placeAt( start.x, start.y )

	for i = 1, #guards do
		guards[i]:reset()
	end

	message.isVisible = false
	state = "playing"
end

local function endRound( newState, pause )
	state = newState
	hero:stop()

	restartTimer = timer.performWithDelay( pause, restartRoom )
end

local function onSpotted( spotter )
	spotter:alert()
	sounds:play( "spotted" )

	-- Idea: instead of restarting, send the guard to search the hero's last seen spot before it gives up.
	endRound( "caught", settings.timing.caughtPause )
end

local function onEscaped()
	message.isVisible = true
	sounds:play( "escaped" )

	endRound( "escaped", settings.timing.escapedPause )
end

-- The round is won once the hero's centre is on the door's tile.
local function isOnDoor()
	return floor( hero.x / tileSize ) == floor( door.x / tileSize ) and floor( hero.y / tileSize ) == floor( door.y / tileSize )
end

local function onEnterFrame()
	local now = getTimer()
	local deltaTime = min( ( now - lastFrameTime ) / 1000, settings.timing.maxFrameTime )
	lastFrameTime = now

	if state ~= "playing" then
		return
	end

	hero:update()

	-- Idea: when two guards meet, let them stop and talk through Weaver, giving the hero a moment to slip past.
	for i = 1, #guards do
		local sentry = guards[i]
		sentry:update( deltaTime )

		-- Idea: let guards hear footsteps, turning toward a moving hero who comes close even outside the cone.
		if guard.canSee( sentry, sentry.facing, hero, settings.vision ) then
			onSpotted( sentry )
			return
		end
	end

	if isOnDoor() then
		onEscaped()
	end
end

local function newMessage( parent )
	local hud = settings.hud

	local group = display.newGroup()
	parent:insert( group )
	group.x, group.y = display.contentCenterX, display.contentCenterY

	local label = display.newText({
		parent = group,
		text = settings.text.escaped,
		font = settings.font.heading,
		fontSize = hud.messageSize,
	})
	label:setFillColor( unpack( settings.colors.text ) )

	local padding = hud.messagePadding
	local backing = display.newRoundedRect( group, 0, 0, label.width + padding * 2, label.height + padding * 2, hud.messageCornerRadius )
	backing:setFillColor( unpack( settings.colors.messageFill ) )
	backing:toBack()

	group.isVisible = false

	return group
end

local function onResize()
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

	local world = display.newGroup()
	sceneGroup:insert( world )

	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	-- The map draws the tiles and adds the sight-blocking wall bodies from its "physics" layer.
	-- Its "game" layer marks the hero's start, the door, and each guard's patrol as a line.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	local map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	world.x = display.contentCenterX - map.designedWidth * 0.5
	world.y = display.contentCenterY - map.designedHeight * 0.5

	tileSize = mapData.tilewidth
	start = map:findObject( "player" )
	door = map:findObject( "door" )

	-- Cones get their own layer under every character, so they never hide a guard or the hero.
	local coneLayer = display.newGroup()
	world:insert( coneLayer )

	controls = input.new( settings.keys )

	hero = player.new({
		parent = world,
		input = controls,
		config = settings.player,
		x = start.x,
		y = start.y,
	})

	local patrols = map:findObjects( "guard" )
	for i = 1, #patrols do
		guards[i] = guard.new({
			parent = world,
			coneParent = coneLayer,
			config = settings.guard,
			vision = settings.vision,
			colors = settings.colors,
			font = settings.font.heading,
			route = guard.routeFromLine( patrols[i] ),
		})
	end

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	local hintBackground = display.newRect( sceneGroup, display.contentCenterX, settings.hud.hintY, 1, 1 )
	hintBackground:setFillColor( unpack( settings.colors.hintBackground ) )

	local hint = display.newText({
		parent = sceneGroup,
		text = settings.text.hint,
		x = display.contentCenterX,
		y = settings.hud.hintY,
		font = settings.font.body,
		fontSize = settings.hud.hintSize,
	})
	hint:setFillColor( unpack( settings.colors.hintText ) )

	hintBackground.width = hint.width + settings.hud.hintPadding * 2
	hintBackground.height = hint.height + settings.hud.hintPadding * 2

	message = newMessage( sceneGroup )

	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })

	sounds = sfx.new( settings.sounds )
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, 0 )

		restartRoom()
		lastFrameTime = getTimer()

		controls:start()
		Runtime:addEventListener( "enterFrame", onEnterFrame )
		Runtime:addEventListener( "resize", onResize )
		onResize()
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		physics.pause()
		state = "paused"

		-- Releasing every key now keeps the hero still while the scene fades out.
		controls:stop()
		hero:stop()

		if restartTimer then
			timer.cancel( restartTimer )
			restartTimer = nil
		end

		for i = 1, #guards do
			guards[i]:stop()
		end

		sounds:stopAll()
		slider:stop()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", onResize )
	end
end

function scene:destroy( event )
	sounds:dispose()
	sounds = nil

	controls = nil
	hero = nil
	guards = {}

	start = nil
	door = nil

	slider = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
