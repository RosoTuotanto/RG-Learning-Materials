local enemy = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sfx = {
	left = audio.loadSound( "assets/audio/sfx/hatLeft.wav" ),
	right = audio.loadSound( "assets/audio/sfx/hatRight.wav" ),
	center = audio.loadSound( "assets/audio/sfx/hatCenter.wav" ),
}

local sheet = graphics.newImageSheet( "assets/images/characters/characters.png", {
	width = 24,
	height = 24,
	numFrames = 10
} )


local animation = {
	{
		name = "move",
		start = 6,
		count = 2,
		time = 250,
		loopCount = 0,
		loopDirection = "forward"
	},
	{
		name = "hide",
		start = 8,
		count = 1,
		loopDirection = "forward"
	}
}

----------------------------------------------------------------------------------

local aiConfig = {
	speed = 60,
	rayDistance = 2,
	rayOffsetY = 4,
	rayDropDistance = 4,
	visionRadius = 50,
	debugLineWidth = 2,
	debugMode = false
}

-- Piirretään viiva hahmon eteen tai taakse ja katsotaan törmääkö se platformiin.
local function checkGroundAhead( character, direction )
	-- Viiva alkaa hahmon edestä tai takaa riippuen suunnasta.
	local startX = character.x + (character.width/2 + aiConfig.rayDistance) * direction
	local startY = character.y + character.height/2 - aiConfig.rayOffsetY

	-- Viiva piirretään suoraan alaspäin.
	local endX = startX
	local endY = startY + aiConfig.rayDropDistance

	-- Suoritetaan raycast, eli katsotaan osuuko viiva fysiikkaobjekteihin.
	local hits = physics.rayCast(startX, startY, endX, endY, "sorted")

	-- Katsotaan osuiko säde platformiin.
	local foundPlatform = false
	if hits then
		for i = 1, #hits do
			local hit = hits[i]
			local hitObject = hit.object

			-- Jos säde osui, niin voimme lopettaa loopin.
			if hitObject.id and hitObject.id == "platform" then
				foundPlatform = true
				break
			end
		end
	end

	-- Piirretään debug viiva, jotta näemme raycast-säteen pelissä.
	if aiConfig.debugMode then
		display.remove(character.debugLine)
		character.debugLine = display.newLine(character._parent, startX, startY, endX, endY)
		character.debugLine:setStrokeColor( 1, 0, 0, 0.9 )
		character.debugLine.strokeWidth = aiConfig.debugLineWidth
	end

	return foundPlatform
end

local function playSFX( dx, distance )
	-- Jos pelaaja on minDistancen sisällä, niin ääni soitetaan 100% voimakkuudella.
	local maxDistance = aiConfig.visionRadius
	local minDistance = 20

	-- Äänenvoimakkuus laskee lineaarisesti maxDistancea lähestyttäessä min. 50%:iin.
	local volumeMultiplier = 1 - (math.max( math.min( distance, maxDistance ), minDistance ) - minDistance) / (maxDistance - minDistance) * 0.5
	local whichSFX

	-- Jos pelaaja ja vihollinen ovat 20 pikselin päässä toisistaan x-akselilla,
	-- niin ne voidaan laskea olevan päällekäin, jolloin soitetaan center sfx.
	local xDistance = math.abs( dx )
	if xDistance < 20 then
		whichSFX = sfx.center

	-- Jos dx on positiivinen, niin vihollinen on pelaajan vasemmalla puolella.
	elseif dx > 0 then
		whichSFX = sfx.left

	-- Jos dx on positiivinen, niin vihollinen on pelaajan oikealla puolella.
	else
		whichSFX = sfx.right

	end

	-- Haetaan vapaa kanava, jolle äänen voi laittaa. Otamme kanavan numeron ylös,
	-- jotta voimme palauttaa kanavan äänenvoimakkuuden äänen soittamisen jälkeen.
	local availableChannel = audio.findFreeChannel( 2 ) -- 1. kanava on varattu musiikille
	local channelVolume = audio.getVolume( { channel = availableChannel } )

	audio.setVolume( channelVolume*volumeMultiplier, { channel = availableChannel } )

	audio.play( whichSFX, {
		channel = availableChannel,
		onComplete = function()
			-- Palautetaan kanavan alkuperäinen äänenvoimakkuus.
			audio.setVolume( channelVolume, { channel = availableChannel } )
		end
	} )
end

-- Tarkkaillaan pelaajan ja hahmon välistä etäisyyttä, sekä näköyhteyttä (line-of-sight).
local function lookForPlayer( character, player )
	local dx = player.x - character.x
	local dy = player.y - character.y
	local distance = math.sqrt(dx * dx + dy * dy)

	if aiConfig.debugMode then
		display.remove(character.visionLine)
	end

	if distance > aiConfig.visionRadius then
		if aiConfig.debugMode then
			character.visionLine = display.newLine(character._parent, character.x, character.y, player.x, player.y)
			character.visionLine:setStrokeColor( 1, 1, 0, 0.9 )
			character.visionLine.strokeWidth = aiConfig.debugLineWidth
		end

		if character.isHiding then
			character:startMoving()
		end

		return
	end

	local hits = physics.rayCast(character.x, character.y, player.x, player.y, "sorted")

	character.canSeePlayer = true

	if hits then
		for i = 1, #hits do
			local hit = hits[i]
			local hitObject = hit.object

			if hitObject.id then
				if hitObject.id == "platform" then
					character.canSeePlayer = false
					break
				end
			end
		end
	end

	-- Draw debug line based on line of sight
	if aiConfig.debugMode then
		character.visionLine = display.newLine(character._parent, character.x, character.y, player.x, player.y)
		character.visionLine.strokeWidth = aiConfig.debugLineWidth

		if character.canSeePlayer then
			character.visionLine:setStrokeColor( 0, 0, 1, 0.9 )
		else
			character.visionLine:setStrokeColor( 1, 0, 0, 0.9 )
		end
	end

	if character.canSeePlayer then
		if not character.isHiding then
			playSFX( dx, distance )
			character:hide()
		end
	else
		if character.isHiding then
			playSFX( dx, distance )
			character:startMoving()
		end
	end
end

----------------------------------------------------------------------------------

function enemy.new( parent, reference )
	-- Otetaan talteen vihollisen alkuperäinen sijainti kartalla.
	local x, y, id = reference.x, reference.y, reference.id
	display.remove( reference )

	local character = display.newSprite( parent, sheet, animation )
	character.x, character.y = x, y
	character.id = id
	character.isEnemy = true

	-- Lisätään parent-ryhmään viittaus debug-piirtämistä varten.
	character._parent = parent

	-- Tehdään fysiikkaobjektista kinemaattinen, jotta sitä voi liikuttaa fysiikoilla.
	physics.addBody( character, "kinematic", {
		isSensor = true,
	} )

	character.xScale = -1
	character:setSequence( "move" )
	character:play()

	-- AI-tilat:
	character.direction = 1
	character.aiActive = false
	character.playerRef = nil
	character.debugLine = nil
	character.visionLine = nil
	character.isHiding = false

	function character:startMoving()
		self:setSequence( "move" )
		self:play()
		self.isHiding = false
	end

	function character:hide()
		self:setSequence( "hide" )
		self:play()
		self.isHiding = true
	end

	-- Päivitetään AI:n tilaa.
	function character:updateAI()
		local hasGroundAhead = checkGroundAhead( character, character.direction )

		if not hasGroundAhead then
			local hasGroundBehind = checkGroundAhead( character, -character.direction )

			if hasGroundBehind then
				character.direction = -character.direction
				character.xScale = -character.xScale
			else
				character:setLinearVelocity(0, 0)
				lookForPlayer( character, character.playerRef )
				return
			end
		end

		local vx
		if character.isHiding then
			vx = 0
		else
			vx = aiConfig.speed * character.direction
		end

		character:setLinearVelocity(vx, 0)
		lookForPlayer( character, character.playerRef )
	end

	function character:startAI( player )
		if self.aiActive then
			print("AI is already running")
			return
		end

		character.playerRef = player
		self.aiActive = true
		Runtime:addEventListener("enterFrame", character.updateAI)
	end

	function character:stopAI( fromFinalize )
		if not self.aiActive then
			-- Ei varoiteta tarpeettomasta AI:n lopettamisesta, jos
			-- lopetuskäsky tulee "finalize"-listener-funktiosta.
			if not fromFinalize then
				print("AI is not running")
			end
			return
		end

		self.aiActive = false
		Runtime:removeEventListener("enterFrame", character.updateAI)
		display.remove(self.debugLine)
		display.remove(self.visionLine)
	end

	-- Jos hahmo tuhotaan, niin varmistetaan, että sen tekoäly on
	function character:finalize()
		self:stopAI( true )
	end

	-- "finalize" event tarkkailee sitä, kun objekti tuhotaan
	-- display.remove() tai object:removeSelf() käskyillä.
	character:addEventListener( "finalize" )

	return character
end

return enemy