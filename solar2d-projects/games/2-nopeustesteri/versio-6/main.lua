-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Asetetaan taustalle uusi väri RGB-muodossa.
display.setDefault( "background", 33/255, 103/255, 235/255 )
-- Asetetaan satunnaislukugeneraattorille seed, jotta arvonta on eri joka käynnistyksellä.
math.randomseed( os.time() )


-----------------------------------------------------
-- Muuttujat:

-- Luodaan pelissä käytetyt taulukot.
local button = {}
local buttonOrder = {}

-- Julistetaan muuttujia.
local indicator
local timerButton

-- Taulukko, jossa on nappuloiden sijaintitiedot.
local buttonData = {
	{ x=240, y=320, rgb = { 1, 0, 0 } }, -- punainen
	{ x=400, y=320, rgb = { 0, 1, 0 } }, -- vihreä
	{ x=560, y=320, rgb = { 0, 0, 1 } }, -- sininen
	{ x=720, y=320, rgb = { 1, 1, 0 } }  -- keltainen
}


-----------------------------------------------------
-- Funktiot:

-- Arvotaan seuraavaksi painettavan pelinappula.
local function nextButton()
	local nextID = math.random( #button )
	table.insert( buttonOrder, nextID )
	-- print( nextID )

	-- Päivitetään indikaattorin sijaintia.
	indicator.x, indicator.y = button[nextID].x, button[nextID].y

	timerButton = timer.performWithDelay( 500, nextButton )
end

-- Funktio, joka kutsutaan aina kun pelinappeihin kosketetaan.
local function onTouch( event )
	if event.phase == "began" then
		print( event.phase, event.target.id )

		-- Tarkistetaan, vastaako painettu nappula seuraavaa odotettua nappulaa.
		if event.target.id == buttonOrder[1] then
			print( "Oikein!" )
			
			-- Poistetaan buttonOrder-taulukon ensimmäinen arvo, jolloin seuraava
			-- painettava nappula on aina taulukon ensimmäinen arvo.
			table.remove( buttonOrder, 1 )

		else
			print( "Väärin!" )

			-- Lopetetaan ajastin, jotta uusia nappuloita ei enää arvota.
			timer.cancel( timerButton )
		end
	end
end

-- Funktio, joka luo nappulan annettuihin koordinaatteihin.
local function createButton( id, data )
	local button = display.newCircle( data.x, data.y, 64 )
	button:addEventListener( "touch", onTouch )
	button:setFillColor( data.rgb[1], data.rgb[2], data.rgb[3] )
	button.id = id

	return button
end


-----------------------------------------------------
-- UI:

-- Luodaan nappulat buttonData-taulukon perusteella.
for i = 1, #buttonData do
	button[i] = createButton( i, buttonData[i] )
end

-- Luodaan indikaattori ensimmäisen nappulan päälle.
indicator = display.newCircle( button[1].x, button[1].y, 80 )
indicator.alpha = 0.5

-----------------------------------------------------
-- Pelin käynnistys:

nextButton()
