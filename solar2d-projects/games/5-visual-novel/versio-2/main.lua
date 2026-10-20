display.setStatusBar( display.HiddenStatusBar )

-- Ladataan composer ja siirrytään menuun.
local composer = require( "composer" )

composer.gotoScene( "scenes.menu", {
	time = 500,
	effect = "fade",
} )

