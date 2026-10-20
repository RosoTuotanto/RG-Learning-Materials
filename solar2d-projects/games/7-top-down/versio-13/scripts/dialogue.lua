-- Dialogimoduuli. Lataa Weaver-tarinamoottorin ja piirtää keskusteluikkunan.
-- Weaver ei piirrä itse mitään ruudulle, joten peli vastaa käyttöliittymästä.
-- Passagen tekstirivit paljastetaan yksi kerrallaan toimintonäppäimellä, ja
-- valittavat vaihtoehdot näytetään vasta viimeisen rivin kohdalla.
-- Keskustelun ollessa auki pelaajan liikkuminen pysäytetään game-scenessä.

local dialogue = {}

--------------------------------------------------------------------------------------
-- Kirjastot, moduulit ja asetukset

local weaver = require( "scripts.spyricStoryWeaver" )
local screen = require( "scripts.screen" )

--------------------------------------------------------------------------------------
-- Muuttujat

-- Tarinan nimi ja tarinatiedoston sijainti. Weaver tunnistaa tarinan tällä nimellä.
-- Nimestä poistetaan välilyönnit, ja Weaver käyttää tulosta muuttujien haussa Lua-koodina,
-- joten nimi ei saa sisältää väliviivaa (esim. "Top-down" hajoaisi vähennyslaskuksi).
local storyName = "Topdown seikkailu"
local storySource = "data/Topdown seikkailu.json"

-- Weaverin oma tallennustiedosto. Weaver kirjoittaa ja lukee sen vain silloin, kun peli
-- kutsuu funktioita dialogue.save ja dialogue.load.
local saveFile = "weaverSave.json"

-- Käytetty fontti ja tekstikoot.
local font = "assets/fonts/munro.ttf"
local textSize = 24

-- Korostetun ja tavallisen vaihtoehdon väri.
local colorNormal = { 0.7, 0.7, 0.7 }
local colorSelected = { 1, 0.82, 0.1 }

-- Keskusteluikkunan osat ja tila. Kun overlay on nil, keskustelu on suljettu.
local overlay
local panelTop
local bodyText
local moreMarker

-- Passagen tekstirivit, joista näkyvissä on rivi textLineIndex.
local textLines = {}
local textLineIndex = 0

-- Passagen vaihtoehdot. choiceLabels ovat pelkkiä tekstejä, kunnes viimeinen rivi
-- näkyy, jolloin niistä rakennetaan valittavat tekstiobjektit choiceTexts-tauluun.
local choiceLabels = {}
local choiceTexts = {}
local choiceTargets = {}
local selectedChoice = 1

-- Pelin antama funktio omien <<...>>-komentojen käsittelyyn (esim. viestin toimitus).
local commandHandler

--------------------------------------------------------------------------------------
-- Paikalliset funktiot

local renderNode

-- Poistetaan näkyvä teksti ja vaihtoehdot ennen uuden piirtämistä.
local function clearContent()
	display.remove( bodyText )
	bodyText = nil

	for i = 1, #choiceTexts do
		display.remove( choiceTexts[i] )
	end
	choiceTexts = {}
end


-- Väritetään vaihtoehdot niin, että valittu erottuu muista.
local function highlightChoice()
	for i = 1, #choiceTexts do
		if i == selectedChoice then
			choiceTexts[i]:setFillColor( unpack( colorSelected ) )
		else
			choiceTexts[i]:setFillColor( unpack( colorNormal ) )
		end
	end
end


-- Rakennetaan keskusteluikkuna: himmennys, paneeli ruudun alaosaan ja jatkomerkki.
local function buildOverlay( parentGroup )
	overlay = display.newGroup()
	parentGroup:insert( overlay )

	-- Himmennetään taustaa, jotta keskustelu erottuu pelimaailmasta.
	local dim = display.newRect( overlay, screen.centerX, screen.centerY, screen.width, screen.height )
	dim:setFillColor( 0, 0.55 )

	-- Keskusteluikkunan tausta ruudun alaosaan.
	local panelWidth = screen.width - 240
	local panelHeight = 180
	local panelCenterY = screen.maxY - panelHeight * 0.5 - 32
	panelTop = panelCenterY - panelHeight * 0.5

	local panel = display.newRoundedRect( overlay, screen.centerX, panelCenterY, panelWidth, panelHeight, 16 )
	panel:setFillColor( 0.12, 0.12, 0.16 )
	panel.strokeWidth = 3
	panel:setStrokeColor( 0.4, 0.4, 0.5 )

	-- Jatkomerkki paneelin oikeassa alakulmassa. Se näkyy, kun passagessa on
	-- vielä paljastamattomia rivejä.
	moreMarker = display.newText({
		parent = overlay,
		text = "...",
		x = screen.centerX + panelWidth * 0.5 - 32,
		y = panelCenterY + panelHeight * 0.5 - 20,
		font = font,
		fontSize = textSize,
	} )
	moreMarker:setFillColor( unpack( colorNormal ) )
	moreMarker.isVisible = false
end


-- Muutetaan kerätyt vaihtoehdot näkyviksi, valittaviksi teksteiksi leipätekstin alle.
local function showChoices()
	local nextY = bodyText.y + bodyText.height + 16
	for i = 1, #choiceLabels do
		local choice = display.newText({
			parent = overlay,
			text = "> " .. choiceLabels[i],
			x = screen.centerX,
			y = nextY,
			width = screen.width - 288,
			font = font,
			fontSize = textSize,
			align = "left",
		} )
		choice.anchorY = 0
		choiceTexts[i] = choice
		nextY = nextY + choice.height + 8
	end

	selectedChoice = 1
	highlightChoice()
end


-- Näytetään vuorossa oleva tekstirivi. Rivit paljastetaan yksi kerrallaan, joten
-- edellinen rivi poistuu ja tilalle piirretään uusi. Viimeisen rivin kohdalla
-- jatkomerkki sammuu ja vaihtoehdot tulevat näkyviin.
local function showCurrentLine()
	clearContent()

	bodyText = display.newText({
		parent = overlay,
		text = textLines[textLineIndex],
		x = screen.centerX,
		y = panelTop + 20,
		width = screen.width - 288,
		font = font,
		fontSize = textSize,
		align = "left",
	} )
	bodyText.anchorY = 0

	local isLastLine = textLineIndex >= #textLines
	moreMarker.isVisible = not isLastLine

	if isLastLine then
		showChoices()
	end
end


-- Haetaan passage (Weaverin koodissa node) ja aloitetaan sen rivien paljastaminen. Weaver palauttaa
-- passagen riveinä, joista jokainen on taulukko. Rivin ensimmäinen arvo kertoo tyypin.
function renderNode( nodeName )
	local line = weaver.getNode( nodeName, storyName )

	textLines = {}
	choiceLabels = {}
	choiceTargets = {}

	for i = 1, #line do
		local lineType = line[i][1]
		if lineType == "text" then
			textLines[#textLines+1] = line[i][2]
		elseif lineType == "link" then
			choiceTargets[#choiceTargets+1] = line[i][3]
			choiceLabels[#choiceLabels+1] = line[i][2]
		elseif commandHandler then
			-- Muut rivit ovat omia <<...>>-komentoja, jotka peli käsittelee itse.
			commandHandler( line[i] )
		end
	end

	-- Passage voi ehtojensa vuoksi jäädä tekstittömäksi. Tyhjä rivi pitää ikkunan
	-- toiminnan ennallaan, ja mahdolliset vaihtoehdot näkyvät silloin heti.
	if #textLines == 0 then
		textLines[1] = ""
	end

	textLineIndex = 1
	showCurrentLine()
end

--------------------------------------------------------------------------------------
-- Julkiset funktiot

-- Ladataan tarina Weaveriin. Tarina alkaa aina alusta, ja Weaver pitää sen tilan
-- muistissa. savefile kertoo, mihin tiedostoon tarinan tila tallennetaan.
function dialogue.init()
	weaver.initStory({
		name = storyName,
		source = storySource,
		savefile = saveFile,
	} )
end


-- Avataan keskustelu annetusta passagesta. Ikkuna lisätään parentGroup-ryhmään,
-- joka ei liiku kameran mukana, jotta keskustelu pysyy paikallaan ruudulla.
-- onCommand on valinnainen funktio, jolla peli käsittelee omat <<...>>-komennot.
function dialogue.open( nodeName, parentGroup, onCommand )
	if overlay then return end

	commandHandler = onCommand
	buildOverlay( parentGroup )
	renderNode( nodeName )
end


-- Näytetään yksittäinen repliikki ilman passagea, esim. pelaajan oma kommentti
-- lukitulla portilla. Ikkuna toimii muuten kuten keskustelussa, ja toimintonäppäin sulkee sen.
function dialogue.showMonologue( text, parentGroup )
	if overlay then return end

	commandHandler = nil
	buildOverlay( parentGroup )

	textLines = { text }
	choiceLabels = {}
	choiceTargets = {}
	textLineIndex = 1
	showCurrentLine()
end


-- Kertoo game-scenelle, onko keskustelu parhaillaan auki.
function dialogue.isOpen()
	return overlay ~= nil
end


-- Käsitellään keskustelun näppäinsyötteet: toimintonäppäin paljastaa seuraavan
-- rivin, ja viimeisen rivin kohdalla nuolilla valitaan vaihtoehto ja
-- toimintonäppäimellä vahvistetaan valinta tai suljetaan keskustelu.
function dialogue.handleKey( action, phase )
	if phase ~= "down" then return end

	if action == "up" then
		if #choiceTexts > 0 then
			selectedChoice = selectedChoice > 1 and selectedChoice - 1 or #choiceTexts
			highlightChoice()
		end
	elseif action == "down" then
		if #choiceTexts > 0 then
			selectedChoice = selectedChoice < #choiceTexts and selectedChoice + 1 or 1
			highlightChoice()
		end
	elseif action == "interact" then
		if textLineIndex < #textLines then
			-- Paljastetaan passagen seuraava rivi.
			textLineIndex = textLineIndex + 1
			showCurrentLine()
		elseif #choiceTargets > 0 then
			renderNode( choiceTargets[selectedChoice] )
		else
			dialogue.close()
		end
	end
end


-- Suljetaan keskustelu ja siivotaan ikkuna pois.
function dialogue.close()
	clearContent()
	display.remove( overlay )
	overlay = nil
	panelTop = nil
	moreMarker = nil
	textLines = {}
	textLineIndex = 0
	choiceLabels = {}
	choiceTargets = {}
	commandHandler = nil
end


-- Luetaan tarinan pysyvän muuttujan ($) arvo Weaverin tallennustaulusta. Lukittu portti
-- (maps/extensions/exit.lua) tarvitsee quest-muuttujan arvon päättääkseen, onko se auki.
function dialogue.getFlag( name )
	local weaverStory = _G["WEAVERx" .. storyName:gsub( "%s+", "" )]
	if weaverStory and weaverStory.saveData then
		return weaverStory.saveData[name]
	end
end


-- Tallennetaan tarinan tila (passagejen käyntikerrat ja tarinan muuttujat) Weaverin
-- tallennustiedostoon. Game-scene kutsuu tätä samalla hetkellä, kun se tallentaa pelitilan.
function dialogue.save()
	weaver.save( storyName )
end


-- Palautetaan tallennettu tarinan tila. Weaver antaa tallennuksesta puuttuville passageille
-- ja muuttujille oletusarvot, joten tarinaan myöhemmin lisätty sisältö ei kaada peliä.
function dialogue.load()
	weaver.load( storyName )
end

--------------------------------------------------------------------------------------

return dialogue
