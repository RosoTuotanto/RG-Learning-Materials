-- Esineiden metatiedot pelin inventoryä varten. Jokaisella esineellä on
-- näyttönimi, lyhyt kuvaus ja frame esineiden image sheetissä maps/items.png.
-- Inventory lukee nämä tiedot ruudukon kuvakkeisiin ja tietolaatikon teksteihin.
-- Näyttötekstit ovat englanniksi kuten muukin pelin käyttöliittymä.

return {
	note = {
		name = "Sealed Note",
		description = "A note from Marlow to Elder Wren. Take it to the elder's house.",
		frame = 1,
	},
	book_red = {
		name = "Red Book",
		description = "A worn red book left lying in the village. Nobody has asked for it.",
		frame = 2,
	},
	coins = {
		name = "Gold Coins",
		description = "A small stack of coins. Not enough to buy anything, but nice to have.",
		frame = 3,
	},
	torch = {
		name = "Torch",
		description = "A trusty torch. It would light the way, if it ever got dark.",
		frame = 4,
	},
	bottle = {
		name = "Glass Bottle",
		description = "An empty glass bottle washed up on the beach.",
		frame = 5,
	},
}
