-- Luodaan yksi taulukko, jonne kaikki kortit lisätään.
local deck = {}

-- Luodaan lista kaikista korteissa käytettävistä maista.
local suit = { "diamonds", "hearts", "clubs", "spades" }

-- Käydään läpi kaikki maat (yhteensä 4).
for i = 1, #suit do
	-- Jokaisessa maassa on 13 korttia, joiden arvot ovat 2-14.
	for number = 2, 14 do
		-- Luodaan kortti taulukkona, jossa on maa ja arvo.
		deck[#deck+1] = { suit=suit[i], number=number }

		-- Tulostetaan kortin tiedot konsoliin, jotta näemme että se toimii.
		print( suit[i], number )
	end
end