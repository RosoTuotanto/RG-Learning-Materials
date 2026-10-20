math.randomseed( os.time() )

-- Fisher-Yates sekoitusalgoritmi.
local function shuffle( t )
	for i = #t, 2, -1 do
		local j = math.random( i )
		t[i], t[j] = t[j], t[i]
	end
end

-- Sääntö, millä table.sort järjestää annetut kortit.
local function compare( a, b )
	-- Jokaisella kortilla on kaksi arvoa: number ja suit.
	-- Järjestetään kortit number-arvon mukaan.
	return a.number < b.number
end

-- Tarkistetaan minkä käden annetut kortit muodostavat.
local function checkHand( card )
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
		print( card[i].suit, card[i].number )

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
			print( "Royal Flush!" )
		else
			print( "Straight Flush!" )
		end

	elseif gotFour then
		print( "Four of a Kind!" )

	elseif gotThree and gotPair then
		print( "Full House!" )

	elseif gotFlush then
		print( "Flush!" )

	elseif gotStraight then
		print( "Straight!" )

	elseif gotThree then
		print( "Three of a Kind!" )

	elseif gotTwoPairs then
		print( "Two Pairs!" )

	elseif gotPair then
		print( "Pair!" )

	else
		print( "High Card!" )
	end
end

-- Luodaan korttipakka.
local deck = {}
local suit = { "diamonds", "hearts", "clubs", "spades" }

for i = 1, #suit do
	for number = 2, 14 do
		deck[#deck+1] = { suit=suit[i], number=number }
	end
end

-- Sekoitetaan korttipakka.
shuffle( deck )

-- Luodaan taulukko pelaajan kädelle.
local hand = {}

-- Lisätään pakan viisi ensimmäistä korttia pelaajan käteen.
for i = 1, 5 do
	hand[i] = deck[i]
end

-- Tarkistetaan pelaajan käsi.
checkHand( hand )