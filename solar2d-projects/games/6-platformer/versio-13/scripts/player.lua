local player = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

local sfxJump = audio.loadSound( "assets/audio/sfx/jump.wav" )

local sheet = graphics.newImageSheet( "assets/images/characters/characters.png", {
	width = 24,
	height = 24,
	numFrames = 10
} )


local animation = {
	{
		name = "move",
		start = 1,
		count = 2,
		time = 250,
		loopCount = 0,
		loopDirection = "forward"
	}
}

----------------------------------------------------------------------------------

-- Poistetaan vanha pelaajahahmon kuva kentästä ja luodaan uusi hahmo sen tilalle.
function player.new( parent, reference )
	-- Otetaan talteen pelaajan alkuperäinen sijainti kartalla.
	local x, y = reference.x, reference.y
	display.remove( reference )

	local newPlayer = display.newSprite( sheet, animation )
	newPlayer.x, newPlayer.y = x, y
	newPlayer.id = "player"
	parent:insert( newPlayer )

	physics.addBody( newPlayer, "dynamic", {
		radius=newPlayer.width*0.5,
		friction = 0.3,
		density = 0.5,
		bounce = 0,
	} )
	-- Estetään pelaajahahmoa pyörimästä fysiikoiden vaikutuksesta.
	newPlayer.isFixedRotation = true

	newPlayer:setSequence( "move" )

	-- Hahmon sisäisiä arvoja:
	local moveSpeed = 150
	local prevDirection = 0
	local ropeTouchCount = 0

	local jumpCount = 0
	local maxJumpCount = 2
	local jumpForce = -1.2
	local isJumping = false

	function newPlayer:move( vx, vy )
		-- Hahmo oli aiemmin paikallaan ja nyt se alkaa liikkua.
		if prevDirection == 0 and vx ~= 0 then
			self:play()
		-- Hahmo liikkui aiemmin ja nyt se pysähtyy.
		elseif prevDirection ~= 0 and vx == 0 then
			self:pause()
		end

		-- Hahmo liikkuu eri suuntaan kuin aiemmin, flipataan hahmo.
		if vx ~= 0 and vx ~= prevDirection then
			self.xScale = -vx
		end

		-- Luetaan pelaajan nykyinen nopeus.
		local _, _vy = self:getLinearVelocity()

		-- Jos pelaaja koskee köyteen, eikä yritä liikkua y-akselilla,
		-- niin pysäytetään pelaajan y-akselin nopeus.
		local touchingRope = ropeTouchCount > 0
		if vy == 0 and ropeTouchCount > 0 then
			_vy = 0
		end

		-- Muutetaan pelaajan liikenopeutta eri tilanteissa:
		----------------------------------------------------
		-- Pelaaja ei yritä liikkua y-akselilla, käytetään pelaajan nykyistä y-akselin nopeutta.
		if vy == 0 then
			self:setLinearVelocity( vx * moveSpeed, _vy )

		-- Pelaaja yrittää liikkua y-akselilla.
		else
			if touchingRope then
				self:setLinearVelocity( vx * moveSpeed, vy * moveSpeed )
			else
				self:setLinearVelocity( vx * moveSpeed, _vy )
			end
		end

		prevDirection = vx
	end

	function newPlayer:touchRope( didTouchBegin )
		local change = didTouchBegin and 1 or -1
		ropeTouchCount = ropeTouchCount + change

		-- Muutetaan pelaajan painovoimaa köyteen koskemisen mukaan.
		if ropeTouchCount > 0 then
			self.gravityScale = 0
		else
			self.gravityScale = 1
		end
	end

	function newPlayer:jump( didJumpBegin )
		if didJumpBegin then
			if jumpCount >= maxJumpCount then
				return
			end
			jumpCount = jumpCount + 1

			audio.play( sfxJump, {
				channel = audio.findFreeChannel(2),
			})

			-- Nollataan pelaajan y-akselin nopeus ennen hyppyä.
			local _vx, _ = self:getLinearVelocity()
			self:setLinearVelocity( _vx, 0 )

			local multiplier = 1
			if self.nearbyTrampoline then
				multiplier = self.nearbyTrampoline:use()
				self.nearbyTrampoline = nil
			end

			self:applyLinearImpulse( 0, jumpForce*multiplier, player.x, player.y )
			isJumping = true

		else
			isJumping = false

		end
	end

	function newPlayer:resetJumpCount()
		jumpCount = 0
	end

	return newPlayer
end

return player