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
local gameState = "gameover"

local gameDeck, instructions

-----------------------------------------------------------
-- Funktiot.
-----------------------------------------------------------

local function touchDeck( event )
	if event.phase == "began" then
		if gameState == "gameover" then
			gameState = "swap"
			instructions.text = "Choose which cards you wish to swap."
			deck.canTouchCard = true

			deck.shuffle()

			-- Poistetaan vanhat kortit ja jaetaan uudet.
			for i = 1, 5 do
				display.remove( hand[i] )
				hand[i] = deck.draw( i )
			end

		elseif gameState == "swap" then
			gameState = "gameover"
			instructions.text = "Tap the deck to draw new cards."
			deck.canTouchCard = false

			-- Vaihdetaan valitut kortit.
			for i = 1, 5 do
				if hand[i].isSelected then
					display.remove( hand[i] )
					hand[i] = deck.draw( i )
				end
			end

			checkHand.get( hand )
		end
	end
	return true
end


-----------------------------------------------------------
-- Pääohjelma.
-----------------------------------------------------------

-- Koska deck-nimi on jo käytössä, annetaan uudelle muuttujalle eri nimi.
gameDeck = deck.new( touchDeck )
instructions = ui.newInstructions()