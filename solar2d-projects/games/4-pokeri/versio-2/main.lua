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

-- Tulostetaan kortit konsoliin.
for i = 1, #deck do
	print( deck[i].suit, deck[i].number )
end