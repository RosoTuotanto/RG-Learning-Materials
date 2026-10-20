local checkHand = require( "scripts.checkHand" )
local deck = require( "scripts.deck" )

math.randomseed( os.time() )

-- Pelaajan kädessä olevat kortit.
local hand = {}

-- Sekoitetaan pakka.
deck.shuffle()

-- Nostetaan 5 uutta korttia.
for i = 1, 5 do
	hand[i] = deck.draw()
end

-- Tarkistetaan pelaajan käsi.
checkHand.get( hand )