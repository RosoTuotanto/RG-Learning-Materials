local ui = {}

-- Nappien ja ilmoituksen visuaaliset asetukset:
local buttonSize = 64
local buttonCorner = 8

-- Ruudun oikea reuna pienellä marginaalilla. screenOriginX on leveillä ruuduilla negatiivinen.
local screenRight = display.actualContentWidth + display.screenOriginX - 8

-- Yksinkertainen nappi, joka kutsuu onPress-funktiota kun sitä painetaan.
function ui.newButton( parent, x, y, label, onPress )
	local group = display.newGroup()
	parent:insert( group )
	group.x, group.y = x, y

	local background = display.newRoundedRect( group, 0, 0, buttonSize, buttonSize, buttonCorner )
	background:setStrokeColor( 0 )
	background.strokeWidth = 2

	local text = display.newText({
		parent = group,
		text = label,
		x = 0,
		y = 0,
		font = "assets/fonts/Micro5-Regular.ttf",
		fontSize = 44
	})
	text:setFillColor( 0 )

	local function onTouch( event )
		if event.phase == "began" then
			onPress()
		end
		return true
	end
	group:addEventListener( "touch", onTouch )

	return group
end

function ui.newPayoutsTable( parent, bet )
	local payouts = require( "data.payouts" )

	-- Luodaan väliaikainen taulukko payouts-datalle.
	local temp = {}
	for _, v in pairs( payouts ) do
		temp[#temp+1] = v
	end

	-- Järjestetään taulukko suurimmasta kertoimesta pienimpään.
	local function compare( a, b )
		return a.multiplier > b.multiplier
	end
	table.sort( temp, compare )

	-- Poistetaan "highCard", koska sillä ei voi voittaa mitään.
	temp[#temp] = nil

	-- Luodaan ryhmä ja sijoitetaan se vasempaan yläkulmaan.
	local group = display.newGroup()
	group.x = display.screenOriginX + 8
	group.y = display.screenOriginY + 8
	parent:insert( group )

	-- Luodaan tekstit loopissa.
	local y = 0
	for i = 1, #temp do
		local text = display.newText({
			parent = group,
			text = temp[i].text .. " - " .. (temp[i].multiplier * bet) .. "$",
			x = 0,
			y = y,
			font = "assets/fonts/Micro5-Regular.ttf",
			align = "left",
			fontSize = 30
		})
		text:setFillColor( 0 )
		-- Ankkurointi vasempaan yläkulmaan.
		text.anchorX, text.anchorY = 0, 0

		-- Tallennetaan kertoimet tekstiin, jotta luvut voidaan päivittää panoksen muuttuessa.
		text.label = temp[i].text
		text.multiplier = temp[i].multiplier

		-- Päivitetään y:n arvo seuraavaa tekstiä varten.
		y = text.y + text.height
	end

	return group
end

-- Päivitetään voittotaulukon luvut nykyisen panoksen mukaan.
function ui.updatePayoutsTable( group, bet )
	for i = 1, group.numChildren do
		local text = group[i]
		text.text = text.label .. " - " .. (text.multiplier * bet) .. "$"
	end
end

-- Päivitetään tekstiä annetun rahamäärän mukaan.
function ui.updateMoneyCounter( textObject, money )
	textObject.text = "You have $" .. money
end

function ui.newMoneyCounter( parent, money )
	-- Luodaan tyhjä teksti ruudun oikeaan yläkulmaan,
	-- jota päivitetään myöhemmin update-funktion kautta.
	local text = display.newText({
		parent = parent,
		text = "",
		x = screenRight,
		y = display.screenOriginY + 8,
		font = "assets/fonts/Micro5-Regular.ttf",
		align = "right",
		fontSize = 32
	})
	text:setFillColor( 0 )

	-- Ankkurointi oikeasta yläkulmasta.
	text.anchorX, text.anchorY = 1, 0

	ui.updateMoneyCounter( text, money )

	return text
end

function ui.newInstructions( parent )
	local text = display.newText({
		parent = parent,
		text = "Tap the deck to draw new cards.",
		x = display.contentCenterX,
		y = display.contentCenterY - 250,
		font = "assets/fonts/Micro5-Regular.ttf",
		align = "center",
		fontSize = 40
	})
	return text
end

-- Päivitetään panostekstiä nykyisen panoksen mukaan.
function ui.updateBetDisplay( textObject, bet )
	textObject.text = "Bet: $" .. bet
end

-- Luodaan panosnäyttö ja sen molemmin puolin napit panoksen säätämiseen.
-- Ne sijoitetaan ruudun oikeaan yläkulmaan rahalaskurin alle, jotta ne eivät peitä kortteja.
function ui.newBetControls( parent, bet, onDecrease, onIncrease )
	local group = display.newGroup()
	parent:insert( group )

	local y = 160

	local betText = display.newText({
		parent = group,
		text = "",
		x = screenRight - 128,
		y = y,
		font = "assets/fonts/Micro5-Regular.ttf",
		align = "center",
		fontSize = 36
	})
	betText:setFillColor( 0 )
	ui.updateBetDisplay( betText, bet )

	ui.newButton( group, screenRight - 225, y, "-", onDecrease )
	ui.newButton( group, screenRight - 32, y, "+", onIncrease )

	return betText
end

-- Luodaan ilmoitus, joka peittää ruudun ja estää muut kosketukset kunnes se suljetaan.
function ui.newNotification( parent, message, onClose )
	local group = display.newGroup()
	parent:insert( group )

	-- Koko ruudun peittävä tausta nappaa kaikki kosketukset alla olevilta objekteilta.
	local blocker = display.newRect(
		group,
		display.contentCenterX,
		display.contentCenterY,
		display.actualContentWidth,
		display.actualContentHeight
	)
	blocker:setFillColor( 0, 0.5 )
	blocker:addEventListener( "touch", function() return true end )

	-- Ilmoituspaneeli keskelle ruutua.
	local panel = display.newRoundedRect( group, display.contentCenterX, display.contentCenterY, 440, 240, 16 )
	panel:setStrokeColor( 0 )
	panel.strokeWidth = 2

	local text = display.newText({
		parent = group,
		text = message,
		x = display.contentCenterX,
		y = display.contentCenterY - 40,
		width = 380,
		font = "assets/fonts/Micro5-Regular.ttf",
		align = "center",
		fontSize = 34
	})
	text:setFillColor( 0 )

	-- Sulkemisnappi poistaa ilmoituksen ja palauttaa pelin normaaliin tilaan.
	ui.newButton( group, display.contentCenterX, display.contentCenterY + 60, "OK", function()
		display.remove( group )
		onClose()
	end )

	return group
end


return ui