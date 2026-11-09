-- The Back to Menu button, drawn above every scene.

local appOverlay = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local layout = require( "data.layout" )
local strings = require( "data.strings" )
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local overlaySettings = layout.overlay

local overlayGroup
local backButton

--------------------------------------------------------------------------------------
-- Private functions

local function goToMenu()
	composer.gotoScene( "scenes.menu", layout.sceneTransition )
end

-- screen.lua runs this after refreshing its edges, both at start and on every resize.
local function reposition()
	local margin = overlaySettings.margin

	backButton.x = screen.minX + margin + overlaySettings.backWidth * 0.5
	backButton.y = screen.minY + margin + overlaySettings.backHeight * 0.5
end

--------------------------------------------------------------------------------------
-- Public functions

-- Call once after composer is required, so the overlay sits above composer's scenes.
function appOverlay.create()
	overlayGroup = display.newGroup()

	backButton = ui.newButton({
		parent = overlayGroup,
		x = 0,
		y = 0,
		width = overlaySettings.backWidth,
		height = overlaySettings.backHeight,
		fontSize = overlaySettings.backFontSize,
		label = strings.back,
		onPress = goToMenu,
	})
	backButton.isVisible = false

	reposition()
	screen.setCallback( reposition )
end

function appOverlay.setBackVisible( isVisible )
	backButton.isVisible = isVisible
	overlayGroup:toFront()
end

return appOverlay
