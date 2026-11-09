-- Template showcase demo: small sample games showing what the Roso Games templates could become.

display.setStatusBar( display.HiddenStatusBar )

math.randomseed( os.time() )

local composer = require( "composer" )
local layout = require( "data.layout" )
local appOverlay = require( "scripts.appOverlay" )

local background = layout.palette.background

-- Set as the default rather than drawn as a rect, so it also covers the letterbox area
-- on screens whose aspect ratio does not match config.lua.
display.setDefault( "background", background[1], background[2], background[3] )

appOverlay.create()

composer.gotoScene( "scenes.menu" )
