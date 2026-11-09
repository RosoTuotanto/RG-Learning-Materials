-- Top-down movement in one room, switchable between free physics movement and tile steps.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local settings = require( "samples.top-down-controls.data.settings" )

local ponytiled = require( "samples.top-down-controls.libs.ponytiled" )

local input = require( "samples.top-down-controls.classes.input" )
local mapGrid = require( "samples.top-down-controls.classes.mapGrid" )
local player = require( "samples.top-down-controls.classes.player" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local grid
local hero

local gridOverlay
local modeLabel
local switchButton

local mode = "free"

--------------------------------------------------------------------------------------
-- Functions

local function setMode( newMode )
	mode = newMode
	hero:setMode( mode )

	gridOverlay.isVisible = mode == "grid"
	modeLabel.text = settings.text.modes[mode]
end

local function toggleMode()
	-- Idea: save the chosen control mode with the template's save system so it stays between sessions.
	setMode( mode == "free" and "grid" or "free" )
end

local function onAction( action )
	if action == "switchMode" then
		toggleMode()
	end
end

local function onSwitchTouch( event )
	if event.phase == "began" then
		toggleMode()
	end

	return true
end

-- The switch button follows the app's back button, which sits at the actual screen corner.
local function positionHud()
	local hud = settings.hud

	switchButton.x = display.screenOriginX + hud.margin + hud.button.width * 0.5
	switchButton.y = display.screenOriginY + hud.margin + hud.backHeight + hud.gap + hud.button.height * 0.5
end

local function onEnterFrame()
	hero:update()
end

local function newSwitchButton( parent )
	local style = settings.hud.button

	local button = display.newGroup()
	parent:insert( button )

	local background = display.newRoundedRect( button, 0, 0, style.width, style.height, style.cornerRadius )
	background:setFillColor( unpack( settings.colors.buttonFill ) )
	background:setStrokeColor( unpack( settings.colors.buttonBorder ) )
	background.strokeWidth = style.strokeWidth

	local label = display.newText({
		parent = button,
		text = settings.text.switchButton,
		font = settings.font.heading,
		fontSize = style.fontSize,
	})
	label:setFillColor( unpack( settings.colors.text ) )

	button:addEventListener( "touch", onSwitchTouch )

	return button
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

	-- The map draws the tiles and adds the wall bodies from its "physics" layer; its "game" layer marks the hero's start.
	local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
	local map = ponytiled.new( mapData, settings.map.folder )
	world:insert( map )

	grid = mapGrid.new( map, mapData )
	world.x = display.contentCenterX - grid.width * 0.5
	world.y = display.contentCenterY - grid.height * 0.5

	gridOverlay = grid:newGridOverlay( world, settings.grid )

	controls = input.new( settings.keys, onAction )

	local start = map:findObject( "player" )
	local column, row = grid:worldToTile( start.x, start.y )
	hero = player.new({
		parent = world,
		grid = grid,
		input = controls,
		config = settings.player,
		column = column,
		row = row,
	})

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	modeLabel = display.newText({
		parent = sceneGroup,
		text = "",
		x = display.contentCenterX,
		y = settings.hud.labelY,
		font = settings.font.heading,
		fontSize = settings.hud.labelSize,
	})
	modeLabel:setFillColor( unpack( settings.colors.text ) )

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

	switchButton = newSwitchButton( sceneGroup )
	positionHud()

	setMode( mode )
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		physics.start()
		physics.setGravity( 0, 0 )

		controls:start()
		Runtime:addEventListener( "enterFrame", onEnterFrame )
		Runtime:addEventListener( "resize", positionHud )
		positionHud()
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		physics.pause()

		-- Releasing every key now keeps the hero still while the scene fades out.
		controls:stop()
		hero:stop()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", positionHud )
	end
end

function scene:destroy( event )
	controls = nil
	grid = nil
	hero = nil

	modeLabel = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
