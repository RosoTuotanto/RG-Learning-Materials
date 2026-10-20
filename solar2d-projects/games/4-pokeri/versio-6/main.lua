display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "background", 148/255, 168/255, 255/255 )

display.setDefault( "minTextureFilter", "nearest" )
display.setDefault( "magTextureFilter", "nearest" )

local checkHand = require( "scripts.checkHand" )
local deck = require( "scripts.deck" )

math.randomseed( os.time() )

-- Pelaajan kädessä olevat kortit.
local hand = {}

-- Sekoitetaan pakka.
deck.shuffle()

-- Nostetaan 5 uutta korttia.
for i = 1, 5 do
	hand[i] = deck.draw( i )
end

-- Tarkistetaan pelaajan käsi.
checkHand.get( hand )