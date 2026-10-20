-- Every piece of text the demo puts on screen, in both languages.
-- The demo defaults to Finnish. On an HTML5 build it switches itself to English when
-- the hosting page sits under /en/, and the button in the top right corner overrides
-- that either way. Code, comments and the repository documents stay English only.

return {
	fi = {
		percentFormat = "%d %%",

		soundLabel = "ÄÄNET",
		soundHint = "Ääniä käytetään vain vaiheissa 6 ja 7.",

		versionTitle = {
			"1. Perusversio",
			"2. Kohde reagoi",
			"3. Kohde liikkuu",
			"4. Ampuja reagoi",
			"5. Ajoitus ja paino",
			"6. Äänet",
			"7. Kaikki lisäykset eivät paranna",
		},

		versionCaption = {
			"Laukaus, luoti, osuma ja HP-palkki. Kaikki tieto, ei lainkaan game feeliä.",
			"Kohde välähtää kirkkaana osuman hetkellä. Osumahetki tulee näkyviin siinä, mihin osuttiin.",
			"Osuma työntää kohdetta taaksepäin. Voima näkyy liikkeenä.",
			"Rekyyli, suuliekki ja lentävä hylsy. Palaute kuuluu myös syylle, ei pelkästään seuraukselle.",
			"Anticipation, easing, hit stop ja screen shake. Samat tehosteet eri ajoituksella tuntuvat aivan erilaisilta.",
			"Laukaus-, osuma- ja hylsyäänet, kummallakin hahmolla omalla sointivärillään. Halvin kerros ja yksi vaikuttavimmista.",
			"Sama kuin edellinen ilman hylsyääntä: se toistuu liian usein ja erottuu liikaa. Kaikki lisätty ei paranna peliä, ja sen erottaa vain kokeilemalla.",
		},
	},

	en = {
		percentFormat = "%d%%",

		soundLabel = "SOUND",
		soundHint = "Sound is only used in steps 6 and 7.",

		versionTitle = {
			"1. Baseline",
			"2. The target reacts",
			"3. The target moves",
			"4. The shooter reacts",
			"5. Timing and weight",
			"6. Sound",
			"7. More is not always better",
		},

		versionCaption = {
			"Shot, bullet, hit, health bar. All of the information and none of the feel.",
			"A colour flash on hit. The moment of contact becomes visible on the thing that was hit.",
			"Knockback on hit. Force reads as displacement.",
			"Recoil, muzzle flash and an ejected casing. Feedback belongs on the cause, not only on the effect.",
			"Anticipation, easing, hit stop and screen shake. The same effects with different timing feel completely different.",
			"Shot, impact and casing audio, with a timbre of its own per fighter. The cheapest layer and one of the strongest.",
			"The same step without the casing sound: it repeats too often and stands out too much. Not everything you add improves the game, and only testing tells.",
		},
	},
}
