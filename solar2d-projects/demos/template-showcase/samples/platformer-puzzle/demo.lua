-- Two physics puzzle rooms: push heavy crates onto pressure switches to hold doors open, then carry the key to the exit.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.platformer-puzzle.data.settings" )

local ponytiled = require( "samples.platformer-puzzle.libs.ponytiled" )

local input = require( "samples.platformer-puzzle.classes.input" )
local player = require( "samples.platformer-puzzle.classes.player" )
local puzzle = require( "samples.platformer-puzzle.classes.puzzle" )
local hud = require( "samples.platformer-puzzle.classes.hud" )
local sfx = require( "samples.platformer-puzzle.classes.sfx" )
local volumeSlider = require( "samples.platformer-puzzle.classes.volumeSlider" )
local pixelFilter = require( "samples.platformer-puzzle.classes.pixelFilter" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local slider
local sheets = {}
local sounds

local roomFiles = settings.map.rooms

local worldLayer
local world
local map
local mechanisms
local hero

local overlay

local roomIndex = 1
local pendingRoom

local isActive = false
local isSolved = false

--------------------------------------------------------------------------------------
-- Functions

local function cancelTimersAndTransitions()
	timer.cancel( settings.tag )
	transition.cancel( settings.tag )
end

local function playSound( name )
	sounds:play( name )
end

local function requestRoom( index )
	pendingRoom = index
end

local function playAgain()
	requestRoom( 1 )
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

local function solveRoom()
	hero:stop()

	-- Idea: count the player's pushes and jumps, and save the best count per room with the template's save system.
	if roomIndex < #roomFiles then
		timer.performWithDelay( settings.nextRoomDelay, function()
			requestRoom( roomIndex + 1 )
		end, 1, settings.tag )

	else
		overlay:showMessage( true )
	end
end

-- Box2D bodies cannot change inside a collision handler, so the puzzle defers the key's body and finishing waits a frame.
local function onHeroCollision( event )
	local other = event.other

	-- Element 1 is the player's solid body; the player handles its own foot sensor.
	if event.phase ~= "began" or event.selfElement ~= 1 or isSolved then
		return
	end

	if other.kind == "key" and not mechanisms.hasKey then
		mechanisms:takeKey( hero )
		overlay:showKey( true )

	elseif other.kind == "exit" and mechanisms.hasKey then
		isSolved = true
		mechanisms:openExit()
		overlay:showKey( false )

		timer.performWithDelay( 1, solveRoom, 1, settings.tag )
	end
end

local function buildRoom( index )
	roomIndex = index
	isSolved = false

	world = display.newGroup()
	worldLayer:insert( world )

	pixelFilter.begin()

	-- The map draws the tiles and adds the ground bodies from its "physics" layer; the points on its "game" layer mark where everything else starts.
	-- Idea: add moving platforms that carry crates across gaps.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. roomFiles[index] ) )
	map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	world.x = display.contentCenterX - map.designedWidth * 0.5
	world.y = settings.roomTop

	mechanisms = puzzle.new({
		parent = world,
		map = map,
		size = mapData.tilewidth,
		images = settings.images,
		config = settings.puzzle,
		tag = settings.tag,
		onSound = playSound,
	})

	pixelFilter.finish()

	local start = map:findObject( "player" )

	hero = player.new({
		parent = world,
		sheet = sheets.characters,
		x = start.x,
		y = start.y,
		input = controls,
		config = settings.player,
	})
	hero:addEventListener( "collision", onHeroCollision )

	overlay:setRoom( index )
	overlay:showKey( false )
	overlay:showMessage( false )
end

-- Rebuilding the room puts every crate, switch, door and the key back where they started.
local function loadRoom( index )
	pendingRoom = nil

	mechanisms:stop()
	display.remove( world )
	cancelTimersAndTransitions()

	buildRoom( index )
end

local function onEnterFrame()
	if not isActive then
		return
	end

	if controls:takePress( "restart" ) then
		requestRoom( roomIndex )
	end

	if pendingRoom then
		loadRoom( pendingRoom )
		return
	end

	if not isSolved then
		hero:update()
	end

	mechanisms:update()
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
	pixelFilter.begin()

	sheets.characters = newSheet( settings.sheets.characters )

	pixelFilter.finish()

	overlay = hud.new({ parent = sceneGroup, settings = settings, onPlayAgain = playAgain })

	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })

	sounds = sfx.new( settings.sounds )

	controls = input.new( settings.keys )

	buildRoom( 1 )
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, settings.gravity )

		controls:start()

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
	mechanisms = nil
	hero = nil

	overlay = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
