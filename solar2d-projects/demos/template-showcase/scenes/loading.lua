-- Shown between a menu press and the sample it opens, so the press changes the screen while the sample builds.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local layout = require( "data.layout" )
local strings = require( "data.strings" )
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )
local appOverlay = require( "scripts.appOverlay" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local loadingSettings = layout.loading

local background
local label
local sampleModule
local framesWaited = 0

--------------------------------------------------------------------------------------
-- Functions

local function fitToScreen()
	background.x = screen.minX + screen.width * 0.5
	background.y = screen.minY + screen.height * 0.5
	background.width = screen.width
	background.height = screen.height

	label.x = screen.centerX
	label.y = screen.centerY
end

local function onEnterFrame()
	framesWaited = framesWaited + 1

	-- A sample's create runs inside gotoScene and blocks drawing, so the loading screen must have been drawn first.
	if framesWaited >= loadingSettings.waitFrames then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		composer.gotoScene( sampleModule, layout.sceneTransition )
	end
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create()
	local sceneGroup = self.view

	background = display.newRect( sceneGroup, 0, 0, 1, 1 )
	background:setFillColor( 0 )

	label = display.newText({
		parent = sceneGroup,
		text = strings.loading,
		x = 0,
		y = 0,
		font = layout.font.heading,
		fontSize = loadingSettings.size,
	})
	ui.setColor( label, layout.palette.text )
end

function scene:show( event )
	local phase = event.phase

	if phase == "will" then
		appOverlay.setBackVisible( false )
		fitToScreen()

	elseif phase == "did" then
		sampleModule = event.params.module
		framesWaited = 0
		Runtime:addEventListener( "enterFrame", onEnterFrame )
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		appOverlay.setBackVisible( true )

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
	end
end

function scene:destroy()
	background = nil
	label = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
