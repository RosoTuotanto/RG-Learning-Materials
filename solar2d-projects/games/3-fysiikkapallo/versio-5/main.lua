-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Ladataan ja käynnistetään fysiikkakirjasto
local physics = require( "physics" )
physics.start()
physics.setDrawMode( "hybrid" )

-------------------------------------------------------------------
-- Muuttujat
local ball, floor, goal, levelBoundary
local timerReset

-- Ääniefektit
local sfxBounce = audio.loadSound( "audio/bounce.wav" )
local sfxScore = audio.loadSound( "audio/score.wav" )
local sfxReset = audio.loadSound( "audio/reset.wav" )

-------------------------------------------------------------------
-- Funktiot

-- Varmista, ettei pelissä ole päällekkäisiä timereita.
local function checkTimer()
	if timerReset then
		timer.cancel( timerReset )
		timerReset = nil
	end
end

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

local function resetBall( self )
	checkTimer()
	audio.play( sfxReset )

	self:setLinearVelocity( 0, 0 )
	self.angularVelocity = 0
	self.x, self.y = self.xStart, self.yStart
	self.rotation = 0
end

-- Funktio, joka kutsutaan aina kun pallo törmää johonkin.
local function onCollision( self, event )
	-- Tarkista, ettei pelaaja koske palloon törmäyksen aikana.
	if not self.isTouched and event.phase == "began" then
		print( self.id, event.other.id )

		local id = event.other.id

		if id == "goal" then
			audio.play( sfxScore )

		elseif id == "boundary" then
			checkTimer()

			timerReset = timer.performWithDelay( 1, function()
				resetBall( self )
			end )

		else
			audio.play( sfxBounce )

		end
	end
end

local function onKeyEvent( event )
	if event.phase == "down" then
		if event.keyName == "space" then
			resetBall( ball )
		end
	end
end

-------------------------------------------------------------------
-- UI

ball = display.newImageRect( "images/ball_blue_small.png", 64, 64 )
ball.x, ball.y = 200, 200
ball.xStart, ball.yStart = ball.x, ball.y
physics.addBody( ball, "dynamic", { radius=32 } )
ball:addEventListener( "touch", dragObject )
-- Lisätään palloon paikallinen collision event listener.
ball.collision = onCollision
ball:addEventListener( "collision" )
ball.id = "ball"

floor = display.newImageRect( "images/block_narrow.png", 64, 256 )
floor.x, floor.y = 200, 500
floor.rotation = 90
physics.addBody( floor, "static" )
floor.id = "floor"

-- Luodaan pelaajalle maali, eli mitä kohti pelaajan tulisi heittää pallo.
goal = display.newImageRect( "images/star.png", 60, 60 )
goal.x, goal.y = 800, 400
physics.addBody( goal, "static", { radius=30, isSensor=true } )
goal.id = "goal"


-- Luodaan näkymätön nelikulmio, joka kattaa koko peliruudun.
levelBoundary = display.newRect(
	display.contentCenterX,
	display.contentCenterY,
	display.actualContentWidth,
	display.actualContentHeight
)

-- Piilotetaan reunat, sillä pelaajan ei tarvitse nähdä niitä.
levelBoundary.isVisible = false

-- Tehdään reunoista chain-tyyppinen fysiikkaobjekti. Ketjut ovat onttoja,
-- jolloin pallo voi liikkua vapaasti reunojen sisällä.
physics.addBody( levelBoundary, "static",
	{
		chain = {
			-- Vasen yläkulma
			-levelBoundary.width*0.5, -levelBoundary.height*0.5,
			-- Oikea yläkulma
			levelBoundary.width*0.5, -levelBoundary.height*0.5,
			-- Oikea alakulma
			levelBoundary.width*0.5, levelBoundary.height*0.5,
			-- Vasen alakulma
			-levelBoundary.width*0.5, levelBoundary.height*0.5
		},
		connectFirstAndLastChainVertex = true,
		isSensor = true
	}
)
-- Lisätään reunoin tunniste.
levelBoundary.id = "boundary"

-------------------------------------------------------------------
-- Runtime listenerit

Runtime:addEventListener( "key", onKeyEvent )
