-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Ladataan ja käynnistetään fysiikkakirjasto
local physics = require( "physics" )
physics.start()
-- physics.setDrawMode( "hybrid" )

-------------------------------------------------------------------
-- Muuttujat
local ball, floor, goal, levelBoundary, warning
local scoreUI, highscoreUI, heightMultiplierUI
local timerReset
local moveUp, moveDown

-- Pisteet
local score = 0
local highscore = 0
-- Heiton aikana osuttujen tasojen kertoimien summa.
local multiplierSum = 0
local goalHeightMultiplier

local multipliers = {
	floor = 2,
	corner = 3,
	obstacle = 5
}

-- Suurin pistemäärä, jonka maalin korkeus voi antaa.
local maxHeightPoints = 5

-- Kuinka monta pikseliä korkeuskertoimen tekstiä siirretään maalin kulmasta.
local heightUIOffset = 4

-- Mistä pelin "laiton alue" alkaa:
local throwMaxX = 350

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

-- Jos pallo ei ole osunut yhteenkään tasoon, kerroin on 1.
local function getActiveMultiplier()
	return math.max( 1, multiplierSum )
end

local function updateScoreUI()
	scoreUI.text = "Score: "..score.." (x"..getActiveMultiplier()..")"
end

local function anticheat()
	-- Tarkistetaan koskeeko pelaaja palloon.
	if ball.isTouched then
		-- Onko pallo liian pitkällä x-akselilla?
		if ball.x >= throwMaxX then
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

-- Lasketaan joka framen aikana maalin korkeuskerroin pelaajan pisteiden
-- laskemista varten ja päivitetään sen UI tekstin sijaintia samalla
local function calculateGoalHeightMultiplier()

	-- Päivitetään sijaintia:
	-- (Huom! Koska maalin sijainti päivittyy transitionilla ja teksti on erillinen objekti,
	-- joka päivittyy enterFramessa, niin se liikkuu aina hieman viiveellä maaliin nähden.)
	heightMultiplierUI.x = goal.x + goal.width*0.5 - heightUIOffset
	heightMultiplierUI.y = goal.y - goal.height*0.5 + heightUIOffset

	-- Lasketaan korkeuskerroin:
	local minY = goal.yStart - goalDistance -- maalin ylin piste y-akselilla
	local maxY = goal.yStart -- maalin aloituspiste y-akselilla

	-- (Huom! Koska transition käyttää easing-funktiota, niin maali voi liikkua hieman
	-- yli määritetyn etäisyyden, jolloin korkeuskerroin voi olla hieman suurempi tai
	-- pienempi kuin haluamme, joten meidän täytyy asettaa maalille minimi ja maksimi arvot.)
	local goalY = math.max( math.min( goal.y, maxY ), minY )

	-- Normalisoidaan etäisyys välille 0-1 ja käännetään se, sillä korkeampi arvo antaa
	-- paremman kertoimen:
	local normalizedHeight = 1 - (goalY - minY) / (maxY - minY)

	-- Lasketaan korkeuskerroin välille 1-maxHeightPoints (1 = alin, maxHeightPoints = korkein)
	-- ja pyöristetään se lähimpään kokonaislukuun:
	goalHeightMultiplier = math.floor( 1 + (maxHeightPoints - 1) * normalizedHeight + 0.5 )

	-- Näytetään korkeuskerroin UI tekstissä:
	heightMultiplierUI.text = goalHeightMultiplier
end

local function dragObject( event )
	local target = event.target
	local phase = event.phase

	if not target.isTouched then
		target.isTouched = true
		target.tempJoint = physics.newJoint( "touch", target, event.x, event.y )
		display.getCurrentStage():setFocus( target )

		-- Nollataan pelaajan pisteet ja kertoimet aina kun hän koskee palloon.
		-- Tämä varmistaa samalla, että pelaaja ei voi huijata, mutta se kuitenkin
		-- jättää pelaajan pisteet näkyviin, kun pallo palautetaan.
		score = 0
		multiplierSum = 0
		target.contacts = {}
		updateScoreUI()

		-- Tätä arvoa käytetään pistekertoimen ja score tekstin päivittämiseen,
		-- jotta ne eivät päivity enää pallon palautuksen jälkeen.
		target.isReset = false
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
	self.contacts = {}

	-- Tarkkaillaan onko pelaaja koskenut palloon.
	self.isReset = true
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

				score = score + 1 * getActiveMultiplier() * goalHeightMultiplier
				updateScoreUI()

				if score > highscore then
					highscore = score
					highscoreUI.text = "Highscore: "..highscore
				end
			end

		elseif id == "boundary" then
			checkTimer()

			timerReset = timer.performWithDelay( 1, function()
				resetBall( self )
			end )

		else
			-- Outline-fysiikkaobjekti koostuu useasta fysiikkamuodosta, joten yksi pomppu niiden saumaan
			-- laukaisee useamman "began"-vaiheen. Lasketaan kosketukset, ettei pomppu tuplaannu.
			local contactCount = self.contacts[id] or 0
			self.contacts[id] = contactCount + 1

			if contactCount == 0 then
				audio.play( sfxBounce )

				-- Varmistetaan, että palloa ei ole juuri palautettu, etteivät kertoimet
				-- esim. muutu kun pallo pomppii palautuksen jälkeen floor-objektin päällä.
				if not self.isReset and multipliers[id] then
					-- Lisätään törmätyn objektin kerroin kertoimien summaan.
					multiplierSum = multiplierSum + multipliers[id]
					updateScoreUI()
				end
			end
		end

	elseif event.phase == "ended" then
		-- Vähennetään kosketusten määrää, kun pallo irtoaa objektista.
		local contactCount = self.contacts[event.other.id]

		if contactCount and contactCount > 0 then
			self.contacts[event.other.id] = contactCount - 1
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
ball.isReset = true
ball.contacts = {}

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
-- Tallennetaan alkuperäinen y-sijainti pisteiden laskemista varten.
goal.yStart = goal.y

local obstacle = display.newImageRect( "images/block_narrow.png", 32, 200 )
obstacle.x, obstacle.y = 640, 160
physics.addBody( obstacle, "static" )
obstacle.id = "obstacle"

local corner = display.newImageRect( "images/block_corner.png", 128, 128 )
corner.x, corner.y = 880, 560
corner.rotation = -90 -- Käännetään kulmaa 90 astetta.
corner.id = "corner"

-- Tehdään kulmasta outline-tyyppinen fysiikkaobjekti.
local outline = graphics.newOutline( 2, "images/block_corner.png" )
physics.addBody( corner, "static", { outline=outline, bounce=1.2, friction=0.1 } )

-- Luodaan varoitus kaikkien muiden objektien päälle.
warning = display.newRect(
	throwMaxX,
	display.contentCenterY,
	display.actualContentWidth,
	display.actualContentHeight
)
warning.anchorX = 0
-- Asetetaan väri RGBA-arvoilla (punainen, vihreä, sininen, läpinäkyvyys).
warning:setFillColor( 1, 0, 0, 0.3 )
warning.isVisible = false

-- Luodaan pisteille UI varoituksen ja muiden UI elementtien jälkeen,
-- jotta pisteet näkyvät kaikkien muiden elementtien päällä.
scoreUI = display.newText(
	"Score: "..score,
	display.screenOriginX + 10,
	display.screenOriginY + 10,
	native.systemFontBold,
	24
)
scoreUI.anchorX, scoreUI.anchorY = 0, 0
updateScoreUI()

highscoreUI = display.newText(
	"Highscore: "..highscore,
	scoreUI.x,
	scoreUI.y + scoreUI.height + 5,
	native.systemFontBold,
	24
)
highscoreUI.anchorX, highscoreUI.anchorY = 0, 0

-- Luodaan korkeuskertoimen UI maalin viereen.
heightMultiplierUI = display.newText(
	"1",
	goal.x + goal.width*0.5 - heightUIOffset,
	goal.y - goal.height*0.5 + heightUIOffset,
	native.systemFontBold,
	24
)
heightMultiplierUI.anchorX, heightMultiplierUI.anchorY = 0, 1

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
Runtime:addEventListener( "enterFrame", calculateGoalHeightMultiplier )

-- Pyöritetään estettä loputtomasti 360 astetta, eli yksi täysi pyörätys.
transition.to( obstacle, { time=5000, rotation=obstacle.rotation-360, iterations=-1 } )

moveUp()