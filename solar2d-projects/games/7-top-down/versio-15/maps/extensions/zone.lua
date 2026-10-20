-- Viestitriggerin extension ponytiled-kartalle.
-- ponytiled kutsuu M.new-funktiota jokaiselle kartan "zone"-tyyppiselle objektille.
-- Triggeri on näkymätön sensori: kun pelaaja astuu siihen, pelaaja kommentoi
-- objektin ominaisuuksissa määriteltyä viestiä (message). once-ominaisuudella
-- triggeri laukeaa vain kerran pelin aikana; muuten se laukeaa uudelleen aina,
-- kun pelaaja poistuu alueelta ja palaa sille.

local M = {}

--------------------------------------------------------------------------------------

-- Kertaalleen lauenneiden once-triggereiden rekisteri: triggered[kartta][nimi] = true.
-- Rekisteri elää game-scenen ulkopuolella ja tallentuu pelitilan mukana, joten
-- kerran lauennut triggeri ei laukea uudelleen edes tallennuksesta jatkettaessa.
local triggered = {}

-- Nykyinen kartta. Game-scene asettaa tämän ennen kartan rakentamista, jotta
-- laukeamiset kirjataan oikean kartan kohdalle.
local currentMap

-- Game-scenen antama funktio, joka näyttää triggerin viestin ruudulla.
M.onMessage = nil

--------------------------------------------------------------------------------------

-- Kerrotaan, mitä karttaa parhaillaan rakennetaan.
function M.setMap( mapName )
	currentMap = mapName
	triggered[mapName] = triggered[mapName] or {}
end


-- Palautetaan rekisteri, jotta pelitilan tallennus voi kirjoittaa sen levylle.
function M.getTriggered()
	return triggered
end


-- Palautetaan tallennettu rekisteri, kun peli jatketaan tallennuksesta ("Continue").
function M.restore( savedTriggered )
	triggered = savedTriggered or {}
end


-- Tyhjennetään rekisteri. Uuden pelin aloitus kutsuu tätä, jotta edellisen
-- pelikerran laukeamiset eivät jää voimaan.
function M.reset()
	triggered = {}
	currentMap = nil
end


function M.new( instance )
	function instance:collision( event )
		-- Reagoidaan vain, kun pelaaja astuu triggeriin (törmäyksen alku).
		if event.phase == "began" and event.other.name == "hero" then
			-- once-triggeri laukeaa vain kerran pelin aikana; rekisteri muistaa sen.
			if self.once then
				if triggered[currentMap][self.name] then return end
				triggered[currentMap][self.name] = true
			end

			-- Viestin näyttäminen on pelkkää piirtämistä, joten sen voi tehdä suoraan
			-- törmäyskäsittelyssä; vain fysiikkaa ja scenejä ei saa muuttaa sen aikana.
			M.onMessage( self.message )
		end
	end

	function instance:finalize()
		instance:removeEventListener( "collision" )
	end

	instance:addEventListener( "collision" )
	instance:addEventListener( "finalize" )

	return instance
end

--------------------------------------------------------------------------------------

return M
