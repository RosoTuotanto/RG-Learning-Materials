-- NPC-hahmon extension ponytiled-kartalle.
-- ponytiled kutsuu M.new-funktiota jokaiselle kartan "npc"-tyyppiselle objektille
-- ja korvaa alkuperäisen Tiled-objektin tämän funktion palauttamalla hahmolla.

local M = {}

--------------------------------------------------------------------------------------

function M.new( instance )
	-- Otetaan talteen tiedot, jotka ponytiled asetti Tiled-objektista.
	local parentLayer = instance.parent
	local x, y = instance.x, instance.y
	-- frame kertoo, mikä image sheetin frame piirretään. node on dialogin passagen
	-- nimi, jota käytämme myöhemmin keskusteluissa (taustahahmoilla ei ole node-ominaisuutta).
	local frame = instance.frame or 1
	local name = instance.name
	local node = instance.node

	-- Poistetaan Tiledin luoma placeholder-objekti. Rakennamme tilalle oman.
	display.remove( instance )

	-- Ladataan sama hahmojen image sheet kuin pelaajalla. Jokainen NPC käyttää eri framea.
	local sheetOptions = {
		width = 32,
		height = 32,
		numFrames = 6,
		sheetContentWidth = 192,
		sheetContentHeight = 32,
	}
	local characterSheet = graphics.newImageSheet( "maps/characters.png", sheetOptions )

	-- Rakennetaan NPC image sheetin oikeasta framesta ja asetetaan se samaan layeriin,
	-- jossa Tiled-objekti oli.
	local npc = display.newImageRect( parentLayer, characterSheet, frame, 32, 32 )
	npc.x, npc.y = x, y

	npc.name = name
	npc.type = "npc"
	-- Säilytetään dialogin passagen nimi, jotta puhekoodi löytää sen myöhemmin.
	npc.node = node

	-- Staattinen fysiikkaobjekti estää pelaajaa kävelemästä hahmon läpi ja antaa
	-- vuorovaikutussäteelle (rayCast) kohteen, johon osua.
	physics.addBody( npc, "static", { radius = 14 } )

	-- Perusasennon y-arvo, johon pomppuanimaatio aina palautuu.
	npc.baseY = y

	-- Pieni pomppu palautteena, kun hahmolle puhutaan: nostetaan hahmoa hetkeksi
	-- ja lasketaan takaisin perusasentoon.
	function npc:bounce()
		transition.cancel( self )
		self.y = self.baseY
		transition.to( self, {
			time = 110,
			y = self.baseY - 8,
			transition = easing.outQuad,
			onComplete = function()
				transition.to( self, { time = 130, y = self.baseY, transition = easing.inQuad } )
			end,
		} )
	end

	-- Perutaan mahdollinen pomppu, kun hahmo poistetaan kentän vaihdon yhteydessä.
	function npc:finalize()
		transition.cancel( self )
	end
	npc:addEventListener( "finalize" )

	return npc
end

--------------------------------------------------------------------------------------

return M
