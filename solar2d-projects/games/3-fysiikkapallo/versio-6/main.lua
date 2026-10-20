-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Ladataan ja käynnistetään fysiikkakirjasto
local physics = require( "physics" )
physics.start()
-- physics.setDrawMode( "hybrid" )

-------------------------------------------------------------------
-- Muuttujat
local ball, floor, goal, levelBoundary, warning
local timerReset
local moveUp, moveDown

-- Ääniefektit
local sfxBounce = audio.loadSound( "audio/bounce.wav" )
local sfxScore = audio.loadSound( "audio/score.wav" )
local sfxReset = audio.loadSound( "audio/reset.wav" )

-- Transition arvot
local goalTime = 2500
local goalDistance = 300
local goalEasing = easing.inOutBack

-------------------------------------------------------------------
-- Funktiot

function moveUp()
	transition.to( goal, { time=goalTime, y=goal.y-goalDistance, onComplete=moveDown, transition=goalEasing } )
end

function moveDown()
	transition.to( goal, { time=goalTime, y=goal.y+goalDistance, onComplete=moveUp, transition=goalEasing } )
end

-- Varmista, ettei pelissä ole päällekkäisiä timereita.
local function checkTimer()
	if timerReset then
		timer.cancel( timerReset )
		timerReset = nil
	end
end

local function anticheat()
	-- Tarkistetaan koskeeko pelaaja palloon.
	if ball.isTouched then
		-- Onko pallo liian pitkällä x-akselilla?
		if ball.x >= 350 then
			if not warning.isVisible then
				warning.isVisible = true
			end
		else
			if warning.isVisible then
				warning.isVisible = false
			end
		end
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
	warning.isVisible = false

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
			-- Hyväksytään maali vain, jos varoitus ei ole näkyvissä.
			if not warning.isVisible then
				audio.play( sfxScore )
			end

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
goal = display.newImageRect( "images/star.png", 40, 40 )
goal.x, goal.y = 800, 400
physics.addBody( goal, "static", { radius=goal.width*0.5, isSensor=true } )
goal.id = "goal"

local obstacle = display.newImageRect( "images/block_narrow.png", 32, 200 )
obstacle.x, obstacle.y = 640, 160
physics.addBody( obstacle, "static" )

local corner = display.newImageRect( "images/block_corner.png", 128, 128 )
corner.x, corner.y = 880, 560
corner.rotation = -90 -- Käännetään kulmaa 90 astetta.

-- Tehdään kulmasta outline-tyyppinen fysiikkaobjekti.
local outline = graphics.newOutline( 2, "images/block_corner.png" )
physics.addBody( corner, "static", { outline=outline, bounce=1.2, friction=0.1 } )

-- Luodaan varoitus kaikkien muiden objektien päälle.
warning = display.newRect(
	display.contentCenterX,
	display.contentCenterY,
	display.actualContentWidth,
	display.actualContentHeight
)
-- Asetetaan väri RGBA-arvoilla (punainen, vihreä, sininen, läpinäkyvyys).
warning:setFillColor( 1, 0, 0, 0.3 )
warning.isVisible = false

-- Luodaan näkymätön nelikulmio, joka kattaa koko peliruudun
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
-- Runtime listenerit, transitionit, yms.

Runtime:addEventListener( "key", onKeyEvent )
Runtime:addEventListener( "enterFrame", anticheat )

-- Pyöritetään estettä loputtomasti 360 astetta, eli yksi täysi pyörätys.
transition.to( obstacle, { time=5000, rotation=obstacle.rotation-360, iterations=-1 } )

moveUp()