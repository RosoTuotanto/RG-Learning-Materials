-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Ladataan ja käynnistetään fysiikkakirjasto
local physics = require( "physics" )
physics.start()
physics.setDrawMode( "hybrid" )

-------------------------------------------------------------------
-- Funktiot

local function dragObject( event )
	local target = event.target
	local phase = event.phase

	if not target.isTouched then
		target.isTouched = true
		target.tempJoint = physics.newJoint( "touch", target, event.x, event.y )
		display.getCurrentStage():setFocus( target )

	else
		if phase == "moved" then
			target.tempJoint:setTarget( event.x, event.y )
		else
			target.isTouched = false
			display.getCurrentStage():setFocus( nil )
			target.tempJoint:removeSelf()
		end
	end
end

-- Funktio, joka kutsutaan aina kun pallo törmää johonkin.
local function onCollision( self, event )
	if event.phase == "began" then
		print( self.id, event.other.id )
	end
end

-------------------------------------------------------------------

local ball = display.newImageRect( "images/ball_blue_small.png", 64, 64 )
ball.x, ball.y = 200, 200
physics.addBody( ball, "dynamic", { radius=32 } )
ball:addEventListener( "touch", dragObject )
-- Lisätään palloon paikallinen collision event listener.
ball.collision = onCollision
ball:addEventListener( "collision" )
ball.id = "ball"

local floor = display.newImageRect( "images/block_narrow.png", 64, 256 )
floor.x, floor.y = 200, 500
floor.rotation = 90
physics.addBody( floor, "static" )
floor.id = "floor"

-- Luodaan pelaajalle maali, eli mitä kohti pelaajan tulisi heittää pallo.
local goal = display.newImageRect( "images/star.png", 60, 60 )
goal.x, goal.y = 800, 400
physics.addBody( goal, "static", { radius=30, isSensor=true } )
goal.id = "goal"