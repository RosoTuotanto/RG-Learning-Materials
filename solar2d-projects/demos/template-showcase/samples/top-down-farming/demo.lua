-- A one-screen farm: till, plant, water and harvest the tile in front of the hero, and sleep to grow the crops.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local json = require( "json" )
local physics = require( "physics" )

local settings = require( "samples.top-down-farming.data.settings" )
local ponytiled = require( "samples.top-down-farming.libs.ponytiled" )

local input = require( "samples.top-down-farming.classes.input" )
local mapGrid = require( "samples.top-down-farming.classes.mapGrid" )
local player = require( "samples.top-down-farming.classes.player" )
local field = require( "samples.top-down-farming.classes.field" )
local fieldView = require( "samples.top-down-farming.classes.fieldView" )
local toolBar = require( "samples.top-down-farming.classes.toolBar" )
local hud = require( "samples.top-down-farming.classes.hud" )
local sfx = require( "samples.top-down-farming.classes.sfx" )
local volumeSlider = require( "samples.top-down-farming.classes.volumeSlider" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local grid
local hero
local farm
local plotView
local target

local bar
local overlay
local fade
local slider
local sounds

local toolIndexForAction = {}
local selectedTool = 1

local isSleeping = false
local sleepTransition = nil

--------------------------------------------------------------------------------------
-- Functions

local function updateHud()
	overlay:update( farm.day, farm.harvestCount )
end

local function selectTool( index )
	-- Slot touches still reach the tool bar through the sleep fade.
	if isSleeping then
		return
	end

	selectedTool = index
	bar:select( index )
end

local function onSleepDone()
	sleepTransition = nil
	isSleeping = false
end

-- Runs while the screen is black, so the new day appears as the fade lifts.
local function onSleepDark()
	farm:advanceDay()
	plotView:refreshAll()
	updateHud()

	-- Idea: save the farm with the template's save system here, so it is waiting the next time the game starts.
	sleepTransition = transition.to( fade, {
		alpha = 0,
		delay = settings.sleep.darkTime,
		time = settings.sleep.fadeInTime,
		onComplete = onSleepDone,
	})
end

local function sleep()
	isSleeping = true
	hero:stop()

	sleepTransition = transition.to( fade, { alpha = 1, time = settings.sleep.fadeOutTime, onComplete = onSleepDark } )
end

local function useTool()
	local column, row = hero:getTargetTile()

	if grid:getObjectType( column, row ) == "bed" then
		sleep()
		return
	end

	-- Idea: add animals that need feeding, as another tool that works on the tiles they stand on.
	local result = farm:useTool( settings.tools[selectedTool].name, column, row )
	if not result then
		return
	end

	plotView:refreshPlot( farm:getPlot( column, row ) )
	updateHud()

	local sound = settings.toolSounds[result]
	if sound then
		sounds:play( sound )
	end
end

local function onAction( action )
	if isSleeping then
		return
	end

	if action == "use" then
		useTool()

	elseif toolIndexForAction[action] then
		selectTool( toolIndexForAction[action] )
	end
end

local function onEnterFrame()
	if not isSleeping then
		hero:update()
	end

	target.x, target.y = grid:tileToWorld( hero:getTargetTile() )
end

local function onResize()
	overlay:position()
	slider:reposition()

	fade.width = display.actualContentWidth
	fade.height = display.actualContentHeight
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

	-- The map draws the tiles and adds the wall bodies from its "physics" layer; its "game" layer marks the start, plots and bed.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	local map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	grid = mapGrid.new( map, mapData )
	world.x = display.contentCenterX - grid.width * 0.5
	world.y = settings.hud.worldY

	farm = field.new( grid:findTiles( "field" ), #settings.field.cropImages )
	plotView = fieldView.new({ parent = world, farm = farm, grid = grid, config = settings.field, colors = settings.colors })

	local outlineSize = grid.tileSize - settings.target.inset * 2
	target = display.newRect( world, 0, 0, outlineSize, outlineSize )
	target:setFillColor( 0, 0 )
	target:setStrokeColor( unpack( settings.colors.target ) )
	target.strokeWidth = settings.target.strokeWidth

	controls = input.new( settings.keys, onAction )

	local start = grid:findTiles( "player" )[1]
	hero = player.new({
		parent = world,
		grid = grid,
		input = controls,
		config = settings.player,
		column = start.column,
		row = start.row,
	})

	for i = 1, #settings.tools do
		toolIndexForAction[settings.tools[i].action] = i
	end

	bar = toolBar.new({
		parent = sceneGroup,
		tools = settings.tools,
		style = settings.toolBar,
		colors = settings.colors,
		font = settings.font.heading,
		onSelect = selectTool,
	})

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	overlay = hud.new( sceneGroup, settings )

	slider = volumeSlider.new({ parent = sceneGroup, font = settings.font.body, style = settings.volumeSlider })
	sounds = sfx.new( settings.sounds )

	fade = display.newRect( sceneGroup, display.contentCenterX, display.contentCenterY, 1, 1 )
	fade:setFillColor( unpack( settings.colors.sleep ) )
	fade.alpha = 0

	selectTool( selectedTool )
	updateHud()
	onResize()
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, 0 )

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

		-- Releasing every key now keeps the hero still while the scene fades out.
		controls:stop()
		hero:stop()

		if sleepTransition then
			transition.cancel( sleepTransition )
			sleepTransition = nil
		end

		sounds:stopAll()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", onResize )
		slider:stop()

		-- A sleep cut short by leaving ends here, so the farm is awake if the scene opens again.
		fade.alpha = 0
		isSleeping = false
	end
end

function scene:destroy( event )
	sounds:dispose()
	sounds = nil

	controls = nil
	grid = nil
	hero = nil
	farm = nil
	plotView = nil
	target = nil

	bar = nil
	overlay = nil
	fade = nil
	slider = nil

	toolIndexForAction = {}
	selectedTool = 1
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
