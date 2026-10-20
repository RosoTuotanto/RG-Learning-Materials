-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Asetetaan taustalle uusi väri RGB-muodossa.
display.setDefault( "background", 33/255, 103/255, 235/255 )

-- Funktio, joka kutsutaan aina kun pelinappeihin kosketetaan.
local function onTouch( event )
	print( event.phase )
end

-- Funktio, joka luo nappulan annettuihin koordinaatteihin.
local function createButton( x, y )
	local button = display.newCircle( x, y, 64 )
	button:addEventListener( "touch", onTouch )

	return button
end

-- Luodaan nappula ja tallennetaan viittaus siihen
local myButton = createButton( 480, 320 )
local myOtherButton = createButton( 620, 320 )
local myLastButton = createButton( 340, 320 )
