-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Asetetaan taustalle uusi väri RGB-muodossa.
display.setDefault( "background", 33/256, 103/256, 235/256 )


-----------------------------------------------------
-- Muuttujat:

-- Luodaan pelissä käytetyt taulukot.
local button = {}
local buttonOrder = {}

-- Julistetaan muuttujia.
local indicator, instructions, scoreText, highscoreText
local timerButton

-- Määritetään muuttujia.
local gameState = "gameover"
local score, highscore = 0, 0

-- Taulukko, joka määrittää jokaisen nappulan sijainnin, muodon, koon, värin ja indikaattorin värin.
local buttonData = {
	{ x=240, y=320, rgb = { 1, 0, 0 }, rgbIndicator = { 1, 0.5, 0.5 }, width = 80, height = 100 }, -- punainen
	{ x=400, y=320, rgb = { 0, 1, 0 }, rgbIndicator = { 0.5, 1, 0.5 }, width = 130, height = 50 }, -- vihreä
	{ x=560, y=320, rgb = { 0, 0, 1 }, rgbIndicator = { 0.5, 0.5, 1 }, radius = 60 }, -- sininen
	{ x=720, y=320, rgb = { 1, 1, 0 }, rgbIndicator = { 1, 1, 0.5 }, radius = 50 }  -- keltainen
}


-----------------------------------------------------
-- Funktiot:

-- Arvotaan seuraavaksi painettavan pelinappula.
local function nextButton()
	local nextID = math.random( #button )
	table.insert( buttonOrder, nextID )

	-- Päivitetään indikaattorin sijaintia, näkyvyyttä ja animoidaan se.
	indicator.x, indicator.y = button[nextID].x, button[nextID].y
	indicator.xScale, indicator.yScale = 0.75, 0.75
	indicator.alpha = 0.75
	transition.to( indicator, { time=200, xScale=1, yScale=1, alpha=0, transition=easing.inOutBack })

	-- Vaihdetaan indikaattorin väriä valitun nappulan mukaan.
	local rgb = button[nextID].rgbIndicator
	indicator:setFillColor( rgb[1], rgb[2], rgb[3] )

	timerButton = timer.performWithDelay( 500, nextButton )
end

-- Funktio, joka kutsutaan aina kun pelinappeihin kosketetaan.
local function onTouchButton( event )
	if gameState == "playing" then
		if event.phase == "began" then

			-- Tarkistetaan, vastaako painettu nappula seuraavaa odotettua nappulaa.
			if event.target.id == buttonOrder[1] then
				score = score + 1 -- kasvatetaan pisteitä yhdellä
				scoreText.text = "score: " .. score

				-- Poistetaan buttonOrder-taulukon ensimmäinen arvo, jolloin seuraava
				-- painettava nappula on aina taulukon ensimmäinen arvo.
				table.remove( buttonOrder, 1 )

			else
				-- Jos pelaajan pisteet ylittävät ennätyksen, päivitä highscore
				if score > highscore then
					highscore = score
					highscoreText.text = "highscore: " .. highscore
				end

				-- Lopetetaan ajastin, jotta uusia nappuloita ei enää arvota.
				timer.cancel( timerButton )

				-- Keskeytetään indikaattorin mahdollinen siirtymä.
				transition.cancel( indicator )

				-- Nollataan pelin asetukset ja näkymä.
				gameState = "gameover"
				instructions.isVisible = true
				indicator.xScale, indicator.yScale = 1, 1
				indicator.alpha = 0

				-- buttonOrder taulukko nollautuu, kun se luodaan uudestaan.
				buttonOrder = {}
			end
		end
	end
end

-- Funktio, joka luo nappulan annettuihin koordinaatteihin.
local function createButton( id, data )
	local newButton

	if data.radius then
		newButton = display.newCircle( data.x, data.y, data.radius )
	else
		newButton = display.newRect( data.x, data.y, data.width, data.height )
	end

	newButton:addEventListener( "touch", onTouchButton )
	newButton:setFillColor( data.rgb[1], data.rgb[2], data.rgb[3] )
	newButton.id = id

	-- Tallennetaan nappuloiden värit indikaattoria varten.
	newButton.rgbIndicator = data.rgbIndicator

	return newButton
end

local function newGame( event )
	if gameState == "gameover" then
		if event.phase == "ended" then
			gameState = "playing"
			instructions.isVisible = false
			score = 0
			scoreText.text = "score: " .. score

			timerButton = timer.performWithDelay( 500, nextButton )
		end
	end
end

-----------------------------------------------------
-- UI:

-- Luodaan nappulat buttonData-taulukon perusteella.
for i = 1, #buttonData do
	button[i] = createButton( i, buttonData[i] )
end

-- Luodaan indikaattori ensimmäisen nappulan päälle.
indicator = display.newCircle( button[1].x, button[1].y, 80 )
-- Käytetään vain alphaa "isVisible":n sijaan, koska indikaattori
-- piilotetaan lyhyellä animaatiolla.
indicator.alpha = 0

-- Luodaan ohjeteksti:
instructions = display.newText({
	text = "click text to start",
	x = 480,
	y = 500,
	fontSize = 52,
} )
instructions:addEventListener( "touch", newGame )

-- Luodaan pisteille musta tausta, jotta ne erottuvat helpommin.
local scoreBG = display.newRect( 160, 140, 300, 120 )
scoreBG:setFillColor( 0 )
scoreBG.anchorX = 0

-- Pelaajan pisteet
scoreText = display.newText({
	text = "score: 0",
	x = 180,
	y = 120,
	fontSize = 44,
} )
scoreText.anchorX = 0

-- Pelaajan ennätys
-- Huom! ennätyksen sijainti on relatiivinen,
-- eli suhteellinen pisteiden sijaintiin.
highscoreText = display.newText({
	text = "highscore: 0",
	x = scoreText.x,
	y = scoreText.y + scoreText.height*0.5 + 20,
	fontSize = 26,
} )
highscoreText.anchorX = 0
