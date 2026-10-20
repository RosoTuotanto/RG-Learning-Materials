-- Ohjausvinkit. Piirtää ruudun alakulmaan pienen, läpikuultavan laatikon, joka
-- kertoo pelaajalle mitä näppäimet tekevät. Näppäimet luetaan pelin sidonnoista,
-- joten uudelleensidotut näppäimet näkyvät vinkeissä oikein.

local hints = {}

--------------------------------------------------------------------------------------
-- Kirjastot, moduulit ja asetukset

-- screen auttaa sijoittamaan laatikon ruudun reunaan.
local screen = require( "scripts.screen" )

-- Sidonnat luetaan ensisijaisesti käyttäjän asetuksista (loadsave.userdata) ja
-- oletusasetukset (data.defaultSettings) toimivat varmuuskopiona.
local loadsave = require( "scripts.loadsave" )
local defaultSettings = require( "data.defaultSettings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Vinkkilaatikon ulkoasu.
local font = "assets/fonts/munro.ttf"
local fontSize = 16
local padding = 10
local margin = 12

-- Näppäinten näyttönimet. Sidonta käyttää Solar2D:n näppäinnimiä (esim. "escape"),
-- jotka muunnetaan tässä pelaajalle selkeämpään muotoon. Nuolinäppäimet niputetaan
-- yhteen "Arrows"-sanan alle.
local keyDisplayNames = {
	escape = "Esc",
	space = "Space",
	up = "Arrows",
	down = "Arrows",
	left = "Arrows",
	right = "Arrows",
}

-- Vinkkirivit. Jokainen rivi kokoaa yhden toiminnon näppäimet ja englanninkielisen
-- selitteen. Rivejä lisätään sitä mukaa kun peliin tulee uusia toimintoja.
local rows = {
	{ actions = { "up", "left", "down", "right" }, label = "Move" },
}

--------------------------------------------------------------------------------------
-- Private functions

-- Palautetaan käytössä olevat keybindit. Peli kopioi asetukset
-- loadsave.userdata-tauluun käynnistyksessä; jos sitä ei ole, käytetään oletuksia.
local function getControlBindings()
	if loadsave.userdata and loadsave.userdata.controls then
		return loadsave.userdata.controls
	end
	return defaultSettings.controls
end


-- Muodostetaan yhden rivin näppäinteksti sidonnoista. Yksittäiset kirjainnäppäimet
-- (esim. w, a, s, d) yhdistetään yhdeksi jonoksi ("WASD") ja nimetyt näppäimet
-- (Space, Arrows, Esc) listataan erikseen. Näin liikkuminen näkyy muodossa
-- "WASD / Arrows" ja vuorovaikutus muodossa "E / Space".
local function formatKeys( actions )
	local controlBindings = getControlBindings()

	local letters = ""
	local named = {}
	local seen = {}

	for actionIndex = 1, #actions do
		local boundKeys = controlBindings[actions[actionIndex]]
		if boundKeys then
			for keyIndex = 1, #boundKeys do
				local keyName = boundKeys[keyIndex]
				local displayName = keyDisplayNames[keyName]
				if displayName then
					if not seen[displayName] then
						seen[displayName] = true
						named[#named+1] = displayName
					end
				else
					letters = letters .. keyName:upper()
				end
			end
		end
	end

	local parts = {}
	if letters ~= "" then
		parts[#parts+1] = letters
	end
	for i = 1, #named do
		parts[#parts+1] = named[i]
	end

	return table.concat( parts, " / " )
end


-- Kootaan kaikki vinkkirivit yhdeksi monirivistekstiksi.
local function buildText()
	local lines = {}
	for i = 1, #rows do
		lines[i] = formatKeys( rows[i].actions ) .. " - " .. rows[i].label
	end
	return table.concat( lines, "\n" )
end

--------------------------------------------------------------------------------------
-- Public functions

-- Luodaan vinkkilaatikko ja lisätään se annettuun scene-ryhmään. Ryhmä ei liiku
-- kameran mukana, joten vinkit pysyvät paikallaan ruudun vasemmassa alakulmassa.
-- Laatikko siivoutuu itsestään scenen mukana, joten erillistä poistoa ei tarvita.
function hints.create( sceneGroup )
	local group = display.newGroup()
	sceneGroup:insert( group )

	local label = display.newText({
		parent = group,
		text = buildText(),
		font = font,
		fontSize = fontSize,
		align = "left",
	} )
	label.anchorX = 0
	label.anchorY = 1

	-- Läpikuultava tausta tekstin taakse, jotta vinkit erottuvat kartasta.
	local background = display.newRoundedRect( group, 0, 0, label.width + padding * 2, label.height + padding * 2, 6 )
	background.anchorX = 0
	background.anchorY = 1
	background:setFillColor( 0, 0.55 )
	background:toBack()

	-- Sijoitetaan laatikko ruudun vasempaan alakulmaan ja teksti reunuksen sisään.
	group.x = screen.minX + margin
	group.y = screen.maxY - margin
	label.x = padding
	label.y = -padding

	return group
end

--------------------------------------------------------------------------------------

return hints
