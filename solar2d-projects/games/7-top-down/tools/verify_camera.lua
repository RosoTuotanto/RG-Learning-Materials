-- Kameran testiskripti. Ajaa pelin oikean classes/camera.lua-moduulin lua5.1:ssä
-- pienillä Solar2D-stubeilla ja tarkistaa, että kamera asettaa karttaryhmän aina kokonaisiin
-- sisältöpikseleihin. Murto-osainen ryhmän sijainti avaa tilejen väliin yhden pikselin
-- saumoja, kun kamera liikkuu. Seuranta ajetaan smoothingilla ja murto-osaisilla
-- kohdesijainneilla, jotka tuottavat murto-osaisia kameran sijainteja.
--
-- Käyttö:  lua5.1 verify_camera.lua [versiokansio]
--   [versiokansio] = polku versiokansioon (oletus: ../versio-15). Kamera on sama kaikissa versioissa.

local projectDir = arg[1] or "../versio-15"
package.path = projectDir .. "/?.lua;" .. package.path

------------------------------------------------------------------------------------
-- Stubit: näytön mitat 960x640-sisältöalueelle ja enterFrame-listenerien keräys.

local frameListeners = {}

display = {
	contentCenterX = 480,
	contentCenterY = 320,
	actualContentWidth = 1138,
	actualContentHeight = 640,
}

Runtime = {
	addEventListener = function( _, name, listener )
		if name == "enterFrame" then
			frameListeners[listener] = true
		end
	end,
	removeEventListener = function( _, name, listener )
		if name == "enterFrame" then
			frameListeners[listener] = nil
		end
	end,
}

local currentTime = 0

system = {
	getTimer = function()
		return currentTime
	end,
}

easing = {
	linear = function( elapsed, duration, start, delta )
		return start + delta * elapsed / duration
	end,
}

local pendingTimers = {}

timer = {
	performWithDelay = function( _, listener )
		pendingTimers[#pendingTimers+1] = listener
		return listener
	end,
	cancel = function() end,
}

local function runFrame()
	currentTime = currentTime + 16.7
	for listener in pairs( frameListeners ) do
		listener( { time = currentTime } )
	end
end

------------------------------------------------------------------------------------
-- Assertit

local failures = 0

local function check( condition, message )
	if condition then
		print( "  PASS  " .. message )
	else
		failures = failures + 1
		print( "  FAIL  " .. message )
	end
end

local function isWhole( value )
	return value == math.floor( value )
end

local camera = require( "classes.camera" )

print( "== kamera-testi (" .. projectDir .. ") ==" )

local mapGroup = { x = 0, y = 0 }
local target = { x = 613.37, y = 402.91 }

camera.init( { { group = mapGroup, delta = 1 } } )
camera.setBounds( { xMin = 569, yMin = 320, xMax = 711, yMax = 512 } )
camera.setTarget( target, { smoothing = 0.3 } )
camera.snapToTarget()
check( isWhole( mapGroup.x ) and isWhole( mapGroup.y ), "snapToTarget asettaa ryhmän kokonaisiin pikseleihin" )

camera.start()

-- Kohde liikkuu murto-osaisin askelin vinottain kuten pelaaja 160 px/s nopeudella.
local allWhole = true
local moved = false
local startX = mapGroup.x
for _ = 1, 240 do
	target.x = target.x + 1.886
	target.y = target.y + 1.886
	runFrame()
	if not isWhole( mapGroup.x ) or not isWhole( mapGroup.y ) then
		allWhole = false
	end
end
if mapGroup.x ~= startX then
	moved = true
end

check( moved, "kamera seuraa liikkuvaa kohdetta" )
check( allWhole, "seurannan aikana ryhmän sijainti on joka framella kokonaisluku" )

-- camera.shake lisää sijaintiin kokonaislukusiirtymiä, joten ryhmä pysyy kokonaisissa pikseleissä.
camera.stop()
camera.shake( { time = 300, magnitude = 4, shakeCount = 4 } )
local shakeWhole = isWhole( mapGroup.x ) and isWhole( mapGroup.y )
for _ = 1, 4 do
	local timers = pendingTimers
	pendingTimers = {}
	for index = 1, #timers do
		timers[index]()
	end
	if not isWhole( mapGroup.x ) or not isWhole( mapGroup.y ) then
		shakeWhole = false
	end
end
check( shakeWhole, "shaken aikana ryhmän sijainti pysyy kokonaislukuna" )

print( "" )
if failures == 0 then
	print( "KAIKKI ASSERTIT LÄPI" )
	os.exit( 0 )
else
	print( failures .. " ASSERTIA EPÄONNISTUI" )
	os.exit( 1 )
end
