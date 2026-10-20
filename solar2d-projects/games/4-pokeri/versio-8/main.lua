-----------------------------------------------------------
-- Asetukset.
-----------------------------------------------------------

display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "background", 148/255, 168/255, 255/255 )
display.setDefault( "minTextureFilter", "nearest" )
display.setDefault( "magTextureFilter", "nearest" )

math.randomseed( os.time() )


-----------------------------------------------------------
-- Moduulit, kirjastot, jne.
-----------------------------------------------------------

local checkHand = require( "scripts.checkHand" )
local deck = require( "scripts.deck" )
local ui = require( "scripts.ui" )


-----------------------------------------------------------
-- Muuttujat.
-----------------------------------------------------------

-- Pelaajan kädessä olevat kortit.
local hand = {}


-----------------------------------------------------------
-- Funktiot.
-----------------------------------------------------------

local function touchDeck( event )
	if event.phase == "began" then
		-- Sekoitetaan pakka.
		deck.shuffle()

		-- Nostetaan 5 uutta korttia.
		for i = 1, 5 do
			hand[i] = deck.draw( i )
		end

		-- Tarkistetaan pelaajan käsi.
		checkHand.get( hand )
	end
	return true
end


-----------------------------------------------------------
-- Pääohjelma.
-----------------------------------------------------------

-- Koska deck-nimi on jo käytössä, annetaan uudelle muuttujalle eri nimi.
local gameDeck = deck.new( touchDeck )
local instructions = ui.newInstructions()