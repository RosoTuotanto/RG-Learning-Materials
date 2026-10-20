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

-------------------------------------------------------------------

local ball = display.newImageRect( "images/ball_blue_small.png", 64, 64 )
ball.x, ball.y = 200, 200
physics.addBody( ball, "dynamic", { radius=32 } )
ball:addEventListener( "touch", dragObject )

local floor = display.newImageRect( "images/block_narrow.png", 64, 256 )
floor.x, floor.y = 200, 500
floor.rotation = 90
physics.addBody( floor, "static" )


