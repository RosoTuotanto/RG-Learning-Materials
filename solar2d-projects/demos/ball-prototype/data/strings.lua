-- Every piece of text the demo puts on screen, in both languages.
-- luacheck: no max line length

return {
	fi = {
		instruction = "Paina ympyrää ja vaihda versiota alareunan napeista.",

		-- Shown both as the title above the caption and on the version buttons.
		versionName = {
			"Versio 1",
			"Versio 9",
		},

		versionCaption = {
			"Ympyrä kasvaa ja palautuu heti. Jos sormi liukuu pois ympyrän päältä, ympyrä jää isoksi, mutta se ei estä vastaamasta kysymykseen: onko ympyrää hyvä painaa?",
			"Kahdeksan iterointikierrosta. Pehmeä animaatio, säädettävät arvot ja kolme korjattua bugia. Tuntuu hiotummalta, mutta vastaa samaan kysymykseen kuin versio 1. Se ei ole enää prototyyppi vaan valmiin ominaisuuden alku.",
		},
	},

	en = {
		instruction = "Press the circle and switch versions with the buttons at the bottom.",

		versionName = {
			"Version 1",
			"Version 9",
		},

		versionCaption = {
			"The circle grows and shrinks back instantly. If your finger slides off the circle, it stays big, but that does not stop it from answering the question: does the circle feel good to press?",
			"Eight rounds of iteration. Smooth animation, adjustable values and three fixed bugs. It feels more polished, but it answers the same question as version 1. It is no longer a prototype but the start of a finished feature.",
		},
	},
}
