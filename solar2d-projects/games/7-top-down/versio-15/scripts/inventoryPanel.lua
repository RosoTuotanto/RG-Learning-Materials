-- Inventoryn käyttöliittymä: ruudun keskelle kiinnittyvä ruudukkopaneeli, jossa on
-- 2x4 slottia, kuvakkeet esineiden image sheetistä, nuolilla liikuteltava kohdistin ja
-- tietolaatikko, joka näyttää valitun slotin esineen nimen ja kuvauksen.
-- Paneeli piirretään scene-ryhmään, joten se ei liiku kameran mukana.
-- Ulkoasu mukailee keskusteluikkunaa (sama himmennys, värit ja munro-fontti).

local inventoryPanel = {}

--------------------------------------------------------------------------------------
-- Kirjastot, moduulit ja asetukset

-- screen keskittää paneelin ruudulle.
local screen = require( "scripts.screen" )
-- inventory säilyttää slottien sisällön ja tarjoaa siirto-operaation.
local inventory = require( "scripts.inventory" )
-- items antaa esineiden näyttönimet, kuvaukset ja image sheetin framet.
local items = require( "data.items" )

--------------------------------------------------------------------------------------
-- Muuttujat

local font = "assets/fonts/munro.ttf"

-- Ruudukon mitat. Paneelin koko lasketaan näistä, joten yhden arvon muuttaminen
-- pitää paneelin edelleen suhteessa oikein.
local slotSize = 96
local slotGap = 18
local columns = 4
local rows = 2
local padding = 26
local titleHeight = 34
local sectionGap = 18
local infoHeight = 120
local iconSize = 64

local gridWidth = columns * slotSize + ( columns - 1 ) * slotGap
local gridHeight = rows * slotSize + ( rows - 1 ) * slotGap
local panelWidth = gridWidth + 2 * padding
local panelHeight = titleHeight + sectionGap + gridHeight + sectionGap + infoHeight + 2 * padding

local slotCount = columns * rows

-- Fonttikoot.
local titleFontSize = 30
local nameFontSize = 26
local descFontSize = 20

-- Värit keskusteluikkunan tyyliin.
local cursorColor = { 1, 0.82, 0.1 }
local textNormal = { 0.7, 0.7, 0.7 }

-- Image sheetin tiedot ovat samat kuin esine-extensionissa (maps/extensions/item.lua).
local sheetOptions = {
	width = 32,
	height = 32,
	numFrames = 5,
	sheetContentWidth = 160,
	sheetContentHeight = 32,
}
local itemSheet

-- Paneelin tila. Kun overlay on nil, reppu on suljettu.
local overlay
local slotPositions = {}
local iconObjects = {}
local cursorFrame
local nameText
local descText

-- Kohdistimen slot (1-slotCount) ja mahdollinen nostettu slot.
local cursorIndex = 1
local heldIndex

--------------------------------------------------------------------------------------
-- Paikalliset funktiot

-- Rakennetaan esineiden image sheet kerran ja pidetään se muistissa seuraavia avauksia varten.
local function getItemSheet()
	if not itemSheet then
		itemSheet = graphics.newImageSheet( "maps/items.png", sheetOptions )
	end
	return itemSheet
end


-- Piirretään esinekuvakkeet uudelleen slottien nykyisestä sisällöstä. Nostettu esine
-- himmennetään, jotta pelaaja näkee kumpi esine on käsissä siirtoa varten.
local function refreshSlots()
	for slotIndex = 1, #iconObjects do
		display.remove( iconObjects[slotIndex] )
	end
	iconObjects = {}

	local sheet = getItemSheet()
	for slotIndex = 1, slotCount do
		local itemId = inventory.getSlot( slotIndex )
		local itemData = itemId and items[itemId]
		if itemData then
			local position = slotPositions[slotIndex]
			local icon = display.newImageRect( overlay, sheet, itemData.frame, iconSize, iconSize )
			icon.x, icon.y = position.x, position.y
			if slotIndex == heldIndex then
				icon.alpha = 0.45
			end
			iconObjects[#iconObjects+1] = icon
		end
	end

	-- Pidetään kohdistin kuvakkeiden päällä.
	if cursorFrame then
		cursorFrame:toFront()
	end
end


-- Päivitetään kohdistimen sijainti ja tietolaatikon teksti valitun slotin mukaan.
local function refreshCursor()
	local position = slotPositions[cursorIndex]
	cursorFrame.x, cursorFrame.y = position.x, position.y

	local itemId = inventory.getSlot( cursorIndex )
	local itemData = itemId and items[itemId]
	if itemData then
		nameText.text = itemData.name
		descText.text = itemData.description
	else
		nameText.text = "Empty slot"
		descText.text = "Move the cursor with the arrow keys."
	end
end

--------------------------------------------------------------------------------------
-- Julkiset funktiot

-- Avataan reppu: rakennetaan paneeli parentGroup-ryhmään, joka ei liiku kameran mukana.
function inventoryPanel.open( parentGroup )
	if overlay then return end

	cursorIndex = 1
	heldIndex = nil

	overlay = display.newGroup()
	parentGroup:insert( overlay )

	-- Himmennetään tausta samalla tavalla kuin keskusteluikkunassa.
	local dim = display.newRect( overlay, screen.centerX, screen.centerY, screen.width, screen.height )
	dim:setFillColor( 0, 0.55 )

	-- Paneeli ruudun keskelle.
	local panel = display.newRoundedRect( overlay, screen.centerX, screen.centerY, panelWidth, panelHeight, 16 )
	panel:setFillColor( 0.12, 0.12, 0.16 )
	panel.strokeWidth = 3
	panel:setStrokeColor( 0.4, 0.4, 0.5 )

	local panelLeft = screen.centerX - panelWidth * 0.5
	local panelTop = screen.centerY - panelHeight * 0.5

	-- Otsikko paneelin yläreunaan.
	display.newText({
		parent = overlay,
		text = "Inventory",
		x = screen.centerX,
		y = panelTop + padding + titleHeight * 0.5,
		font = font,
		fontSize = titleFontSize,
	} )

	-- Lasketaan jokaisen slotin keskipiste ja piirretään slotin tausta.
	local gridLeft = panelLeft + padding
	local gridTop = panelTop + padding + titleHeight + sectionGap
	slotPositions = {}
	for slotIndex = 1, slotCount do
		local column = ( slotIndex - 1 ) % columns
		local row = math.floor( ( slotIndex - 1 ) / columns )
		local centerX = gridLeft + column * ( slotSize + slotGap ) + slotSize * 0.5
		local centerY = gridTop + row * ( slotSize + slotGap ) + slotSize * 0.5
		slotPositions[slotIndex] = { x = centerX, y = centerY }

		local slotBackground = display.newRoundedRect( overlay, centerX, centerY, slotSize, slotSize, 8 )
		slotBackground:setFillColor( 0.18, 0.18, 0.24 )
		slotBackground.strokeWidth = 2
		slotBackground:setStrokeColor( 0.32, 0.32, 0.4 )
	end

	-- Kohdistin: väritetty ääriviiva ilman täyttöä valitun slotin ympärille.
	cursorFrame = display.newRoundedRect( overlay, slotPositions[cursorIndex].x, slotPositions[cursorIndex].y, slotSize + 8, slotSize + 8, 10 )
	cursorFrame:setFillColor( 0, 0 )
	cursorFrame.strokeWidth = 4
	cursorFrame:setStrokeColor( unpack( cursorColor ) )

	-- Tietolaatikko ruudukon alle.
	local infoTop = gridTop + gridHeight + sectionGap
	local infoBox = display.newRoundedRect( overlay, screen.centerX, infoTop + infoHeight * 0.5, gridWidth, infoHeight, 8 )
	infoBox:setFillColor( 0.08, 0.08, 0.11 )
	infoBox.strokeWidth = 2
	infoBox:setStrokeColor( 0.32, 0.32, 0.4 )

	nameText = display.newText({
		parent = overlay,
		text = "",
		x = gridLeft + 16,
		y = infoTop + 14,
		font = font,
		fontSize = nameFontSize,
		align = "left",
	} )
	nameText.anchorX = 0
	nameText.anchorY = 0
	nameText:setFillColor( unpack( cursorColor ) )

	descText = display.newText({
		parent = overlay,
		text = "",
		x = gridLeft + 16,
		y = infoTop + 52,
		width = gridWidth - 32,
		font = font,
		fontSize = descFontSize,
		align = "left",
	} )
	descText.anchorX = 0
	descText.anchorY = 0
	descText:setFillColor( unpack( textNormal ) )

	refreshSlots()
	refreshCursor()
end


-- Kertoo game-scenelle, onko reppu parhaillaan auki.
function inventoryPanel.isOpen()
	return overlay ~= nil
end


-- Käsitellään repun näppäinsyötteet: nuolet siirtävät kohdistinta, toimintonäppäin
-- nostaa esineen, asettaa sen tai vaihtaa esineiden slotteja, ja inventory-näppäin sulkee repun.
function inventoryPanel.handleKey( action, phase )
	if phase ~= "down" then return end

	if action == "right" then
		cursorIndex = cursorIndex % slotCount + 1
		refreshCursor()
	elseif action == "left" then
		cursorIndex = ( cursorIndex - 2 ) % slotCount + 1
		refreshCursor()
	elseif action == "down" then
		cursorIndex = cursorIndex + columns
		if cursorIndex > slotCount then
			cursorIndex = cursorIndex - slotCount
		end
		refreshCursor()
	elseif action == "up" then
		cursorIndex = cursorIndex - columns
		if cursorIndex < 1 then
			cursorIndex = cursorIndex + slotCount
		end
		refreshCursor()
	elseif action == "interact" then
		if heldIndex then
			-- Asetetaan nostettu esine: eri slotiin vievä siirto vaihtaa esineet
			-- keskenään, samaan slotiin palautus vain laskee esineen takaisin.
			if heldIndex ~= cursorIndex then
				inventory.move( heldIndex, cursorIndex )
			end
			heldIndex = nil
			refreshSlots()
			refreshCursor()
		elseif inventory.getSlot( cursorIndex ) then
			-- Nostetaan valitun slotin esine siirrettäväksi.
			heldIndex = cursorIndex
			refreshSlots()
		end
	elseif action == "inventory" then
		inventoryPanel.close()
	end
end


-- Suljetaan reppu ja siivotaan paneeli pois.
function inventoryPanel.close()
	display.remove( overlay )
	overlay = nil
	iconObjects = {}
	slotPositions = {}
	cursorFrame = nil
	nameText = nil
	descText = nil
	heldIndex = nil
end

--------------------------------------------------------------------------------------

return inventoryPanel
