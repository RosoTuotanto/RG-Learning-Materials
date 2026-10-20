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

-- Nosta uusi kortti.
function deck.draw( position)
	cardNumber = cardNumber + 1

	-- _alaviiva tarkoittaa "private" muuttujaa.
	-- Tämä on vain koodin lukemisen apuväline.
	local _suit = deckData[cardNumber].suit
	local _number = deckData[cardNumber].number

	-- Luodaan kortti-objekti.
	local card = display.newImageRect( "assets/images/" .. _suit .. "_" .. _number .. ".png", cardSize, cardSize )
	card.id = position -- Käytetään kortin sijaintia sen id:nä.

	-- Lisätään maski korttiin ja skaalataan se kurtin kokoon sopivaksi.
	card:setMask( mask )
	local maskScale = cardSize / 64
	card.maskScaleX = maskScale
	card.maskScaleY = maskScale

	-- Lasketaan korttien sijainti x-akselilla dynaamisesti.
	local xStart = display.contentCenterX - (cardSize*0.65625 + cardPadding)*2
	card.x = xStart + (position-1)*(cardSize*0.65625 + cardPadding)
	card.y = y

	-- Lisätään kortin tiedot.
	card.suit = _suit
	card.number = _number

	-- Lisätään event listener.
	card:addEventListener( "touch", touchCard )

	return card
end

-- Luo uusi pakka.
function deck.new( listener )
	-- Luodaan uusi display group keskelle ruutua.
	local group = display.newGroup()
	group.x = display.contentCenterX
	group.y = yDeck

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