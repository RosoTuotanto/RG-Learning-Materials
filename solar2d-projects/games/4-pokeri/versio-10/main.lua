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
-- Display groupit.
-----------------------------------------------------------

local groupBackground = display.newGroup() -- alimmainen
local groupForeground = display.newGroup() -- keskimmäinen
local groupUI = display.newGroup() -- päällimmäinen


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

local function onDeal()
	if gameState == "dealingStart" then
		gameState = "swap"
		instructions.text = "Choose which cards you wish to swap."
		deck.canTouchCard = true

	elseif gameState == "dealingSwap" then
		gameState = "gameover"
		instructions.text = "Tap the deck to draw new cards."
		deck.canTouchCard = false

		checkHand.get( hand )
	end
end

local function touchDeck( event )
	if event.phase == "began" then
		if gameState == "gameover" then
			gameState = "dealingStart"
			instructions.text = "Dealing..."
			deck.canTouchCard = false

			deck.shuffle()

			-- Koska discard-funktio kutsutaan järjestyksessä, niin
			-- viimeinen saamamme arvo on viimeisen kortin aika.
			local requiredDelay = 0

			-- Poistetaan vanhat kortit, jos niitä on.
			if #hand > 0 then
				for i = 1, 5 do
					requiredDelay = deck.discard( hand[i], groupBackground, gameDeck, i )
				end
			end

			-- Jaetaan viiveellä uudet kortit tilalle.
			timer.performWithDelay( requiredDelay + 100, function()
				for i = 1, 5 do
					hand[i] = deck.draw( groupForeground, i, gameDeck, i, 5, onDeal )
				end
			end )

		elseif gameState == "swap" then
			gameState = "dealingSwap"
			instructions.text = "Dealing..."
			deck.canTouchCard = false

			local currentCard, totalCards = 1, 0

			-- Selvitetään montako korttia pelaaja haluaa vaihtaa.
			for i = 1, 5 do
				if hand[i].isSelected then
					totalCards = totalCards + 1
				end
			end

			local requiredDelay = 0

			-- Vaihdetaan valitut kortit.
			for i = 1, 5 do
				if hand[i].isSelected then
					requiredDelay = deck.discard( hand[i], groupBackground, gameDeck, currentCard )
					currentCard = currentCard + 1
				end
			end

			if totalCards == 0 then
				onDeal()
			else
				-- Jaetaan viiveellä uudet kortit tilalle.
				timer.performWithDelay( requiredDelay + 100, function()
					currentCard = 1 -- nollataan montako korttien laskuri.
					for i = 1, 5 do
						if hand[i].isSelected then
							hand[i] = deck.draw( groupForeground, i, gameDeck, currentCard, totalCards, onDeal )
							currentCard = currentCard + 1
						end
					end
				end )
			end

		end
	end
	return true
end


-----------------------------------------------------------
-- Pääohjelma.
-----------------------------------------------------------

-- Koska deck-nimi on jo käytössä, annetaan uudelle muuttujalle eri nimi.
gameDeck = deck.new( groupBackground, touchDeck )
instructions = ui.newInstructions( groupUI )