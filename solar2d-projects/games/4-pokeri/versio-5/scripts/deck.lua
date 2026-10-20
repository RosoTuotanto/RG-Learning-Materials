local deck = {}

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

-- Fisher-Yates sekoitusalgoritmi.
function deck.shuffle()
	for i = #deckData, 2, -1 do
		local j = math.random( i )
		deckData[i], deckData[j] = deckData[j], deckData[i]
	end
	cardNumber = 0
end

-- Nosta uusi kortti.
function deck.draw()
	cardNumber = cardNumber + 1
	local card = deckData[cardNumber]
	return card
end

return deck