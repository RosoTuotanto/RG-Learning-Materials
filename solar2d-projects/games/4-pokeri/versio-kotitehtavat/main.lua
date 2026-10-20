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

local payouts = require( "data.payouts" )
local checkHand = require( "scripts.checkHand" )
local deck = require( "scripts.deck" )
local ui = require( "scripts.ui" )
local sfx = require( "scripts.sfx" )


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

local gameDeck, instructions, moneyCounter, payoutsTable, betDisplay, notification

-- Pelaajan varallisuus ja panos.
local playerMoney = 500
local bet = 10

-- Panoksen ala- ja yläraja sekä muutosaskel.
local betMin = 10
local betMax = 100
local betStep = 10


-----------------------------------------------------------
-- Funktiot.
-----------------------------------------------------------

-- Näytetään ilmoitus ruudulla ja estetään muut painallukset kunnes se suljetaan.
local function showNotification( message )
	-- Näytetään vain yksi ilmoitus kerrallaan.
	if notification then
		return
	end
	notification = ui.newNotification( groupUI, message, function()
		notification = nil
	end )
end

-- Muutetaan seuraavan kierroksen panosta annetulla määrällä.
local function changeBet( change )
	-- Panosta voi muuttaa vain kierrosten välissä, ei kesken kierroksen.
	if gameState ~= "gameover" then
		return
	end

	-- Nappeja ei voi painaa kesken korttien animaation.
	if deck.isAnimating() then
		return
	end

	local newBet = bet + change

	-- Pysytään panoksen rajojen sisällä.
	if newBet < betMin or newBet > betMax then
		return
	end

	bet = newBet
	ui.updateBetDisplay( betDisplay, bet )
	ui.updatePayoutsTable( payoutsTable, bet )
	sfx.play( "bet" )
end

local function onDeal()
	if gameState == "dealingStart" then
		gameState = "swap"
		instructions.text = "Choose which cards you wish to swap."
		deck.canTouchCard = true

	elseif gameState == "dealingSwap" then
		gameState = "gameover"
		instructions.text = "Tap the deck to draw new cards."
		deck.canTouchCard = false

		local result = checkHand.get( hand )
		local resultText = payouts[result[1]].text

		if result[1] == "highCard" then
			local cardValue = hand[5].number
			local cardText

			if cardValue == 14 then
				cardText = "an Ace"
			elseif cardValue == 13 then
				cardText = "a King"
			elseif cardValue == 12 then
				cardText = "a Queen"
			elseif cardValue == 11 then
				cardText = "a Jack"
			else
				cardText = "a " .. cardValue
			end

			instructions.text = "You got " .. cardText .. " High!\nTap the deck to draw new cards."
		else
			local winnings = bet * payouts[result[1]].multiplier

			-- Lisätään voitot pelaajan rahoihin ja päivitetään teksti.
			playerMoney = playerMoney + winnings
			ui.updateMoneyCounter( moneyCounter, playerMoney )
			sfx.play( "win" )

			instructions.text = "You got " .. resultText .. " You won $" .. winnings .. "!\nTap the deck to draw new cards."
		end

		-- Korostetaan voittavat kortit ilman korttien kosketusääntä, ettei se peitä voittoääntä.
		for i = 1, 5 do
			if not result[2] or hand[i].number == result[2] or hand[i].number == result[3] then
				deck.toggleCard( hand[i], false )
			end
		end
	end
end

local function touchDeck( event )
	if event.phase == "began" then
		-- Estetään pakan painaminen kesken kortin animaation.
		if deck.isAnimating() then
			return true
		end

		if gameState == "gameover" then
			-- Tarkistetaan, että pelaajalla on varaa aloittaa uusi kierros.
			if playerMoney - bet < 0 then
				showNotification( "Not enough money for a $" .. bet .. " bet." )
				return true
			end

			-- Vähennetään panos ja päivitetään teksti.
			playerMoney = playerMoney - bet
			ui.updateMoneyCounter( moneyCounter, playerMoney )
			sfx.play( "bet" )

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

			-- Sekoitetaan pakka näkyvästi ja jaetaan uudet kortit vasta sen jälkeen.
			timer.performWithDelay( requiredDelay + 100, function()
				local shuffleTime = deck.shuffleAnimation( gameDeck )
				timer.performWithDelay( shuffleTime, function()
					for i = 1, 5 do
						hand[i] = deck.draw( groupForeground, i, gameDeck, i, 5, onDeal )
					end
				end )
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
moneyCounter = ui.newMoneyCounter( groupUI, playerMoney )
payoutsTable = ui.newPayoutsTable( groupUI, bet )

-- Panoksen säätönapit luodaan viimeisenä, jotta ne piirtyvät muun UI:n päälle.
betDisplay = ui.newBetControls( groupUI, bet,
	function() changeBet( -betStep ) end,
	function() changeBet( betStep ) end
)