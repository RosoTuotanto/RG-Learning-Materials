-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Asetetaan taustalle uusi väri RGB-muodossa.
display.setDefault( "background", 33/255, 103/255, 235/255 )

-- Taulukko, johon tallennamme luodut pelinappulat.
local button = {}

-- Taulukko, jossa on nappuloiden sijaintitiedot.
local buttonData = {
	{ x=240, y=320, rgb = { 1, 0, 0 } }, -- punainen
	{ x=400, y=320, rgb = { 0, 1, 0 } }, -- vihreä
	{ x=560, y=320, rgb = { 0, 0, 1 } }, -- sininen
	{ x=720, y=320, rgb = { 1, 1, 0 } }  -- keltainen
}

-- Funktio, joka kutsutaan aina kun pelinappeihin kosketetaan.
local function onTouch( event )
	print( event.target.id, event.phase )
end

-- Funktio, joka luo nappulan annettuihin koordinaatteihin.
local function createButton( id, data )
	local button = display.newCircle( data.x, data.y, 64 )
	button:addEventListener( "touch", onTouch )
	button:setFillColor( data.rgb[1], data.rgb[2], data.rgb[3] )
	button.id = id

	return button
end

-- Luodaan nappulat buttonData-taulukon perusteella.
for i = 1, #buttonData do
	button[i] = createButton( i, buttonData[i] )
end
