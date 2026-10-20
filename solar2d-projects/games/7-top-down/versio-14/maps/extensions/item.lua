-- Esineen extension ponytiled-kartalle.
-- ponytiled kutsuu M.new-funktiota jokaiselle kartan "item"-tyyppiselle objektille
-- ja korvaa alkuperäisen Tiled-objektin tämän funktion palauttamalla esineellä.

local inventory = require( "scripts.inventory" )

local M = {}

--------------------------------------------------------------------------------------

function M.new( instance )
	-- Otetaan talteen tiedot, jotka ponytiled asetti Tiled-objektista.
	local parentLayer = instance.parent
	local x, y = instance.x, instance.y
	-- frame kertoo esineiden image sheetin framen, item on esineen tunnus ja name objektin nimen.
	local frame = instance.frame or 1
	local itemId = instance.item
	local name = instance.name

	-- Poistetaan Tiledin luoma placeholder-objekti. Rakennamme tilalle oman.
	display.remove( instance )

	-- Jos esine on jo poimittu aiemmin, sitä ei luoda uudelleen kartalle. Näin
	-- kertaalleen poimittu esine ei ilmesty takaisin, kun palaamme tähän karttaan.
	if inventory.isCollected( name ) then
		return nil
	end

	-- Ladataan esineiden image sheet. Frame 1 on viesti, 2 kirja, 3 kolikot, 4 soihtu ja 5 pullo.
	local sheetOptions = {
		width = 32,
		height = 32,
		numFrames = 5,
		sheetContentWidth = 160,
		sheetContentHeight = 32,
	}
	local itemSheet = graphics.newImageSheet( "maps/items.png", sheetOptions )

	-- Rakennetaan esine oikeasta framesta samaan layeriin, jossa Tiled-objekti oli.
	local item = display.newImageRect( parentLayer, itemSheet, frame, 32, 32 )
	item.x, item.y = x, y

	item.name = name
	item.type = "item"
	-- Säilytetään esineen tunnus reppua varten.
	item.item = itemId

	-- Staattinen fysiikkaobjekti antaa vuorovaikutussäteelle (rayCast) kohteen, johon osua.
	physics.addBody( item, "static", { radius = 12 } )

	-- Poimitaan esine reppuun ja poistetaan se kartalta. Rekisteriin merkitään,
	-- ettei esine enää ilmesty uudelleen tähän karttaan palatessa. Jos reppu on täynnä,
	-- esine jää kartalle eikä sitä merkitä poimituksi. Palautetaan true onnistuneesta
	-- poiminnasta ja false, jos reppu oli täynnä.
	function item:pickup()
		if inventory.add( self.item ) then
			inventory.markCollected( self.name )
			display.remove( self )
			return true
		end
		return false
	end

	return item
end

--------------------------------------------------------------------------------------

return M
