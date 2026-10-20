-- Siirtymäportin extension ponytiled-kartalle.
-- ponytiled kutsuu M.new-funktiota jokaiselle kartan "exit"-tyyppiselle objektille.
-- Portti on näkymätön sensori: kun pelaaja koskettaa sitä, siirrytään
-- objektin ominaisuuksissa määriteltyyn karttaan ja spawn-pisteeseen.
-- Portin voi lukita ominaisuuksilla requiredQuest ja lockedMessage: portti aukeaa
-- vasta, kun tarinan quest-muuttuja on saavuttanut requiredQuest-arvon.

local composer = require( "composer" )
local dialogue = require( "scripts.dialogue" )

local M = {}

--------------------------------------------------------------------------------------

-- Estää siirtymän laukeamasta useaan kertaan. Muuttuja on yhteinen kaikille porteille,
-- joten mikään toinen portti ei voi laueta siirtymän ollessa jo käynnissä.
local transitioning = false

-- Game-scenen antama funktio, joka näyttää lukitun portin viestin ruudulla.
M.onLocked = nil

--------------------------------------------------------------------------------------

function M.new( instance )
	function instance:collision( event )
		-- Reagoidaan vain, kun pelaaja saapuu porttiin (törmäyksen alku).
		if event.phase == "began" and event.other.name == "hero" then
			if transitioning then return end

			-- Lukittu portti ei päästä pelaajaa läpi ennen kuin tehtävä on edennyt
			-- tarpeeksi pitkälle. Pelaaja kommentoi sen sijaan, miksi ei mene sinne.
			if self.requiredQuest and dialogue.getFlag( "quest" ) < self.requiredQuest then
				M.onLocked( self.lockedMessage )
				return
			end

			transitioning = true

			-- Otetaan kohdekentän tiedot talteen. Ne tulevat Tiled-objektin ominaisuuksista.
			local targetMap = self.targetMap
			local targetSpawn = self.targetSpawn

			-- Tehdään siirtymä vasta seuraavalla framella. Fysiikkaa ja scenejä ei saa
			-- muuttaa kesken törmäyskäsittelyn, joten odotamme törmäyksen valmistumista.
			-- Siirrytään refresh-scenen kautta, jotta uusi kartta rakennetaan alusta.
			timer.performWithDelay( 1, function()
				composer.gotoScene( "scenes.refresh", {
					params = { mapName = targetMap, spawnName = targetSpawn },
				} )
			end )
		end
	end

	-- Kun portti poistetaan (kenttää vaihdettaessa), sallitaan siirtymät taas.
	function instance:finalize()
		transitioning = false
		instance:removeEventListener( "collision" )
	end

	instance:addEventListener( "collision" )
	instance:addEventListener( "finalize" )

	return instance
end

--------------------------------------------------------------------------------------

return M
