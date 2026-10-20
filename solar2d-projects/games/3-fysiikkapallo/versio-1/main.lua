-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Ladataan ja käynnistetään fysiikkakirjasto
local physics = require( "physics" )
physics.start()
physics.setDrawMode( "hybrid" )

local ball = display.newImageRect( "images/ball_blue_small.png", 64, 64 )
ball.x, ball.y = 200, 200
physics.addBody( ball, "dynamic", { radius=32 } )

local floor = display.newImageRect( "images/block_narrow.png", 64, 256 )
floor.x, floor.y = 200, 500
floor.rotation = 90
physics.addBody( floor, "static" )