math.randomseed( os.time() )

-- Fisher-Yates sekoitusalgoritmi.
local function shuffle( t )
	for i = #t, 2, -1 do
		local j = math.random( i )
		t[i], t[j] = t[j], t[i]
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
	-- Tulostetaan kortit konsoliin, jotta näemme mitä pelaaja sai.
	print( hand[i].suit, hand[i].number )
end