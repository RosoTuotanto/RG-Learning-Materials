local ui = {}

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

		-- Päivitetään y:n arvo seuraavaa tekstiä varten.
		y = text.y + text.height
	end

	return group
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
		x = display.actualContentWidth - display.screenOriginX - 8,
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


return ui