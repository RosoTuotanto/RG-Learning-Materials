-- Piilotetaan puhelimen yläreunassa oleva status bar.
display.setStatusBar( display.HiddenStatusBar )

-- Asetetaan taustalle uusi väri RGB-muodossa.
display.setDefault( "background", 33/255, 103/255, 235/255 )

-- Funktio, joka kutsutaan aina kun pelinappia kosketetaan.
local function onTouch( event )
	print( event.phase )
end

-- Luodaan pelinappula keskelle peliruutua.
local button = display.newCircle( 480, 320, 64 )
button:addEventListener( "touch", onTouch )
