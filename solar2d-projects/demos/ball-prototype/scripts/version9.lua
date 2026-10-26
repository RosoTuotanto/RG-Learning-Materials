-- Määritä millä kertoimella ympyrää tulee skaalata sitä painettaessa.
local scaleFactor = 1.5
-- Määritä kuinka kauan skaalauksen animaation tulee kestää (millisekunteina).
local scaleTime = 500

-- Lasketaan kauanko animaatiossa on vielä aikaa jäljellä (millisekunteina).
local function calculateRemainingTime( currentScale, targetScale, fullTime )
	-- Lisätään pieni toleranssi tarkistukseen, jotta vältetään liukuluku-epätarkkuuksista
	if math.abs(currentScale - targetScale) < 0.0001 then
		return 0
	end

	local scaleDifference = math.abs( targetScale - currentScale )
	local fullScaleDifference = math.abs( targetScale - (currentScale < targetScale and 1 or scaleFactor) )
	local remainingTime = (scaleDifference / fullScaleDifference) * fullTime

	return remainingTime
end

local function touchButton( event )
	-- Lua pitää totena kaikkea muuta paitsi arvoja false ja nil. Ehto
	-- "if event.target.isTouched then" täyttyisi siis silloin, kun kosketus on jo
	-- alkanut. Alun "not" kääntää tämän, joten tähän haaraan mennään vain, kun
	-- isTouched on false tai nil eli kosketus on vasta alkamassa.
	if not event.target.isTouched then
		-- Kosketus alkaa, niin merkitse kosketus alkaneeksi ja kasvata ympyrää muuttujan scaleFactor verran.
		event.target.isTouched = true

		-- Aloitetaan animaatio, joka skaalaa ympyrää halutulla kertoimella.
		transition.cancel( event.target ) -- Keskeytetään mahdollinen käynnissä oleva animaatio.

		-- Selvitetään animaation jäljellä oleva kesto.
		local time = calculateRemainingTime( event.target.xScale, scaleFactor, scaleTime )
		transition.to( event.target, { time=time, xScale=scaleFactor, yScale=scaleFactor, onComplete=function()
			print( '"began" - skaalaus valmis' )
		end } )

		-- Aseta fokus tähän ympyrään, jotta saamme "ended" -vaiheen aina.
		display.getCurrentStage():setFocus( event.target )

	else
		if event.phase == "ended" then
			-- Kosketus loppuu, niin merkitse kosketus loppuneeksi, ja aloita
			-- uusi animaatio, jossa ympyrä palautetaan sen alkuperäiseen kokoon.
			event.target.isTouched = false

			transition.cancel( event.target ) -- Keskeytetään mahdollinen käynnissä oleva animaatio.

			-- Selvitetään animaation jäljellä oleva kesto.
			local time = calculateRemainingTime( event.target.xScale, 1, scaleTime )

			transition.to( event.target, { time=time, xScale=1, yScale=1, onComplete=function()
				print( '"ended" - skaalaus valmis' )
			end } )

			-- Poista fokus tästä ympyrästä.
			display.getCurrentStage():setFocus( nil )
		end
	end

	return true
end

local button = display.newCircle( display.contentCenterX, display.contentCenterY, 60 )
button:addEventListener( "touch", touchButton )

return button
