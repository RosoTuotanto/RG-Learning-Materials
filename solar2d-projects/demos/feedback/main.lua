-- Feedback demo: the same fight, replayed with one more layer of feedback each time.

display.setStatusBar( display.HiddenStatusBar )

local composer = require( "composer" )
local layout = require( "data.layout" )

local background = layout.palette.background

-- Set as the default rather than drawn as a rect, so it also covers the letterbox area
-- on screens whose aspect ratio does not match config.lua.
display.setDefault( "background", background[1], background[2], background[3] )

composer.gotoScene( "scenes.demo" )
