display.setStatusBar( display.HiddenStatusBar )

-- Onko peli developer-tilassa vai ei?
_G.developerMode = true

-- Ladataan composer ja siirrytään menuun.
local composer = require( "composer" )

composer.gotoScene( "scenes.menu", {
	time = 500,
	effect = "fade",
} )

