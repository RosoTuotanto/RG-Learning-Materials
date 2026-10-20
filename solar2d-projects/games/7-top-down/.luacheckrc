-- Luacheck-asetukset Top-down-seikkailu-opetuspelille.
-- Tiedosto on pelin juuressa, jotta jokainen "<Peli> - versio N" -vaihekansio
-- voidaan tarkistaa täältä. Luacheck etsii .luacheckrc:n työhakemistosta ylöspäin.

max_line_length = 160

-- Solar2D käyttää Lua 5.1:tä.
std = "lua51"

-- Solar2D:n globaalit (kirjoitettavissa, jotta wrapperit voivat tarvittaessa korvata ne).
globals = {
	"audio",
	"composer",
	"display",
	"easing",
	"graphics",
	"native",
	"network",
	"physics",
	"Runtime",
	"system",
	"timer",
	"transition",
	-- config.lua ja build.settings asettavat nämä.
	"application",
	"settings",
}

-- Vendoroidut kolmannen osapuolen tiedostot (Ponywolf ponytiled ja Corona Labs xml)
-- eivät ole pelin omaa koodia, joten niitä ei tarkisteta.
exclude_files = {
	"**/com/**",
	-- spyricStoryWeaver.lua vendoroidaan sellaisenaan eikä sitä koskaan muokata.
	"**/scripts/spyricStoryWeaver.lua",
}

-- Solar2D:n scene- ja event-koodissa usein käyttämättä jäävät nimet, sekä
-- 542 = tyhjä if-haara (scenejen will/did -rungot ovat tarkoituksella tyhjiä).
ignore = {
	"self",
	"event",
	"arg",
	"sceneGroup",
	"_",
	"542",
}
