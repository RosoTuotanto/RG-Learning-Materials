local checkHand = {}

-- Sääntö, millä table.sort järjestää annetut kortit.
local function compare( a, b )
	-- Jokaisella kortilla on kaksi arvoa: number ja suit.
	-- Järjestetään kortit number-arvon mukaan.
	return a.number < b.number
end

-- Tarkistetaan minkä käden annetut kortit muodostavat.
function checkHand.get( card )
	-- Järjestetään annetut kortit suuruusjärjestykseen.
	table.sort( card, compare )

	-- Luodaan frekvenssitaulukko: kuinka monta kertaa
	-- kukin kortti esiintyy pelaajan kädessä.
	local frequency = {}
	for i = 2, 14 do
		frequency[i] = 0
	end

	-- Muistetaan edellinen maa ja numero.
	local prevSuit
	local prevNumber

	-- Pokerikäsien oletusarvot.
	local gotFlush = true
	local gotStraight = true

	-- Käydään annetut kortit läpi.
	for i = 1, #card do
		-- print( card[i].suit, card[i].number )

		-- Päivitetään frekvenssitaulukkoa.
		local number = card[i].number
		frequency[number] = frequency[number] + 1

		local suit = card[i].suit
		if not prevSuit then
			prevSuit = suit
		elseif prevSuit ~= suit then
			gotFlush = false
		end

		if not prevNumber or number == prevNumber + 1 then
			prevNumber = number
		else
			gotStraight = false
		end
	end

	-- Toisin kuin värin ja suoran kohdalla, nämä kädet
	-- voivat toteutua vain, jos kortteja esiintyy
	-- tietyllä lukumäärällä.
	local gotFour
	local gotThree
	local gotPair
	local gotTwoPairs

	-- Käydään frekvenssitaulukko läpi ja tarkistetaan
	-- löytyykö pareja, kolmosia tai nelosia.
	for i = 2, 14 do
		local count = frequency[i]
		-- print( i, count )

		if count == 2 then
			if not gotPair then
				gotPair = i
			else
				gotTwoPairs = i
			end
		elseif count == 3 then
			gotThree = i
		elseif count == 4 then
			gotFour = i
		end
	end

	-- Tarkistetaan mahdolliset kädet parhaimmasta huonoimpaan.
	if gotFlush and gotStraight then
		-- Jos korkein kortti on ässä, kyseessä on kuningasvärisuora.
		if card[5].number == 14 then
			return { "royalFlush" }
		else
			return { "straightFlush" }
		end

	elseif gotFour then
		return { "fourOfAKind", gotFour }

	elseif gotThree and gotPair then
		return { "fullHouse" }

	elseif gotFlush then
		return { "flush" }

	elseif gotStraight then
		return { "straight" }

	elseif gotThree then
		return { "threeOfAKind", gotThree }

	elseif gotTwoPairs then
		return { "twoPairs", gotPair, gotTwoPairs }

	elseif gotPair then
		return { "pair", gotPair }

	else
		-- Kortit ovat suuruusjärjestyksessä,
		-- eli suurin korttin on viimeisenä.
		return { "highCard", card[5].number }
	end
end

return checkHand