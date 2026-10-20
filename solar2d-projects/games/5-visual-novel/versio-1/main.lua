display.setStatusBar( display.HiddenStatusBar )

-- Ladataan composer ja siirrytään menuun.
local composer = require( "composer" )
-- Huom!
-- Tiedostopolut erotellaan pisteellä (.), ei viivoilla.
composer.gotoScene( "scenes.menu" )


