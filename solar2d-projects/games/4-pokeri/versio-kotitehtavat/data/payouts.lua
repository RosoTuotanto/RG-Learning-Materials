-- Palautetaan pokerikäsien tiedot taulukkona.
return {
	-- Kertoimet ovat esimerkinomaisia.
	["royalFlush"] = { text="Royal Flush!", multiplier=50 },
	["straightFlush"] = { text="Straight Flush!", multiplier=20 },
	["fourOfAKind"] = { text="Four of a Kind!", multiplier=15 },
	["fullHouse"] = { text="Full House!", multiplier=10 },
	["flush"] = { text="Flush!", multiplier=7 },
	["straight"] = { text="Straight!", multiplier=5 },
	["threeOfAKind"] = { text="Three of a Kind!", multiplier=3 },
	["twoPairs"] = { text="Two Pairs!", multiplier=2 },
	["pair"] = { text="a Pair!", multiplier=1 },
	["highCard"] = { text="High!", multiplier=0 },
}