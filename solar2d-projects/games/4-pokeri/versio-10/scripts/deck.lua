local deck = {}

deck.canTouchCard = false

-----------------------------------------------------------
-- Asetukset.
-----------------------------------------------------------

-- Luodaan korttien hit mask vain kerran.
local mask = graphics.newMask( "assets/images/card_mask.png" )

-- Korttien visuaalisia asetuksia:
local cardSize = 160
local cardPadding = 20 -- korttien välinen etäisyys
local y = 520

-- Kortin valinnan visuaaliset asetukset:
local cardSelectedY = 20
local cardSelectedScale = 1.1

local yDeck = display.contentCenterY - 80


-----------------------------------------------------------
-- Muuttujat.
-----------------------------------------------------------

-- Pelikierroksen aikana nostetut kortit.
local cardNumber = 0

-- Luodaan korttipakka.
local deckData = {}
local suit = { "diamonds", "hearts", "clubs", "spades" }

for i = 1, #suit do
	for number = 2, 14 do
		deckData[#deckData+1] = { suit=suit[i], number=number }
	end
end


-----------------------------------------------------------
-- Funktiot.
-----------------------------------------------------------

-- Funktio, joka suoritetaan kun korttia painetaan.
local function touchCard( event )
	if event.phase == "began" and deck.canTouchCard then
		local target = event.target
		-- print( target.id, target.suit, target.number )

		-- Käännetään isSelected-muuttuja päinvastaiseksi.
		target.isSelected = not target.isSelected

		if target.isSelected then
			-- Kortti valittuna: suurennetaan ja nostetaan.
			target.xScale, target.yScale = cardSelectedScale, cardSelectedScale
			target.y = target.y - cardSelectedY
		else
			-- Kortti ei enää valittuna: palautetaan normaaliksi.
			target.xScale, target.yScale = 1, 1
			target.y = target.y + cardSelectedY
		end
	end
	return true
end

-- Fisher-Yates sekoitusalgoritmi.
function deck.shuffle()
	for i = #deckData, 2, -1 do
		local j = math.random( i )
		deckData[i], deckData[j] = deckData[j], deckData[i]
	end
	cardNumber = 0
end

-- Siirretään kortti pakan alle ja tuhotaan se.
function deck.discard( card, newParent, gameDeck, discardNumber )
	-- Siirretään kortti samaan ryhmään kuin pakka.
	newParent:insert( card )
	-- Siirretään kortti ryhmän alimmaiseksi.
	card:toBack()

	-- Kortin vaihdon siirtoon liittyvät nopeus muuttujat.
	local time = 300
	local delay = (discardNumber-1)*100

	-- Käännetään kortti ensiksi ympäri ja siirretään se vasta sen jälkeen pakkaan.
	transition.to( card.front.path, {
		time = time*0.5,
		delay = delay,
		x1 = cardSize*0.5,
		x2 = cardSize*0.5,
		x3 = -cardSize*0.5,
		x4 = -cardSize*0.5,

		onComplete = function()
			transition.to( card.back.path, {
				time = time*0.5,
				x1 = 0,
				x2 = 0,
				x3 = 0,
				x4 = 0,
			})
		end
	})

	-- Koska palautamme kortit pakan pohjalle, niin haluamme siis siirtää
	-- ne korttipakan alimmaisen, eli ensimmäisenä luodun kortin kohdalle.
	local bottomCard = gameDeck.card[1]

	-- Odotetaan kortin kääntöä, eli huomioidaan se delay:ssä.
	transition.to( card, {
		time = time,
		delay = time + delay + 50, -- Lisätään pieni viive käännön jälkeen.
		x = gameDeck.x + bottomCard.x,
		y = gameDeck.y + bottomCard.y,
		rotation = bottomCard.rotation,
		onComplete = function()
			display.remove( card )
		end
	})

	-- Palautetaan kortin siirtämiseen ja tuhoamiseen kulutettu kokonaisaika.
	return time*2 + delay + 100 -- Käytämme tääs pientä lisäviivettä.
end

-- Nosta uusi kortti.
function deck.draw( parent, position, gameDeck, drawNumber, totalDraws, callback )
	cardNumber = cardNumber + 1

	-- _alaviiva tarkoittaa "private" muuttujaa.
	-- Tämä on vain koodin lukemisen apuväline.
	local _suit = deckData[cardNumber].suit
	local _number = deckData[cardNumber].number

	-- Luodaan kortti-ryhmä.
	local card = display.newGroup()
	parent:insert( card )
	card:toBack()
	card.id = position -- Käytetään kortin sijaintia sen id:nä.

	-- Luodaan kortin etu- ja takapuoli.
	card.front = display.newImageRect( card, "assets/images/" .. _suit .. "_" .. _number .. ".png", cardSize, cardSize )
	card.back = display.newImageRect( card, "assets/images/card_back.png", cardSize, cardSize )

	-- Lisätään maski korttiin ja skaalataan se kurtin kokoon sopivaksi.
	card:setMask( mask )
	local maskScale = cardSize / 64
	card.maskScaleX = maskScale
	card.maskScaleY = maskScale

	-- Asetetaan kortti pakan päällimmäisen kortin kohdalle
	local topCard = gameDeck.card[#gameDeck.card]
	card.x = gameDeck.x + topCard.x
	card.y = gameDeck.y + topCard.y
	card.rotation = topCard.rotation

	-- Lasketaan korttien lopullinen sijainti x-akselilla dynaamisesti.
	local xStart = display.contentCenterX - (cardSize*0.65625 + cardPadding)*2
	card.xTo = xStart + (position-1)*(cardSize*0.65625 + cardPadding)
	card.yTo = y

	-- Lisätään kortin tiedot.
	card.suit = _suit
	card.number = _number

	-- Lisätään event listener.
	card:addEventListener( "touch", touchCard )

	-------------------------------------------
	-- Kortin animaatiot:

	-- Etupuoli vääristetään piiloon.
	card.front.path.x1 = cardSize*0.5
	card.front.path.x2 = cardSize*0.5
	card.front.path.x3 = -cardSize*0.5
	card.front.path.x4 = -cardSize*0.5

	-- Kortin siirtymä.
	transition.to( card, {
		delay = 200 * (drawNumber-1),
		time = 500,
		x = card.xTo,
		y = card.yTo,
		rotation = 0, -- palautetaan kortti normaaliin asentoon.
		onComplete = function()
			if drawNumber == totalDraws then
				callback()
			end
		end
	})

	-- Käännetään kortin takapuoli piiloon.
	transition.to( card.back.path, {
		delay = (drawNumber-1)*200,
		time = 250,
		x1 = cardSize*0.5,
		x2 = cardSize*0.5,
		x3 = -cardSize*0.5,
		x4 = -cardSize*0.5,
		onComplete = function()
			-- Käännetään kortin etupuoli näkyviin.
			transition.to( card.front.path, {
				time = 250,
				x1 = 0,
				x2 = 0,
				x3 = 0,
				x4 = 0
			})
		end
	})

	return card
end

-- Luo uusi pakka.
function deck.new( parent, listener )
	-- Luodaan uusi display group keskelle ruutua.
	local group = display.newGroup()
	group.x = display.contentCenterX
	group.y = yDeck

	parent:insert( group )

	-- Luodaan groupiin taulukko, johon tallennetaan kaikki kortit.
	group.card = {}

	-- Tämä on vain visuaalinen efekti, eikä se liity pelin logiikkaan.
	-- Tämän takia luomme vain 20 korttia, vaikka oikeassa pelissä on 52 korttia.
	for i = 1, 20 do
		-- Luodaan kortin taustakuva ja lisätään se groupiin.
		local card = display.newImageRect( group, "assets/images/card_back.png", cardSize, cardSize )

		-- Annetaan korteille pieniä satunnaisia variaatioita.
		card.x = math.random( -1, 1 )
		card.y = -i*2
		card.rotation = math.random( -2, 2 )

		-- Lisätään kortti groupin card-taulukkoon.
		group.card[#group.card+1] = card
	end

	group:addEventListener( "touch", listener )

	return group
end


return deck