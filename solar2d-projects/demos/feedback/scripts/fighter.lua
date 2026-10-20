-- One of the two boxes: its body, its gun, its health bar and its anchor position.
-- The fighter owns what it is made of and defers how it reacts to the effects module,
-- which is where every feedback layer lives.

local fighter = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )
local fightData = require( "data.fight" )
local effects = require( "scripts.effects" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local settings = layout.fighter
local palette = layout.palette

local bodyCenterY = layout.floorY - settings.bodyHeight * 0.5
local gunCenterY = bodyCenterY + settings.gunOffsetY

-- The gun outline, in a space whose origin sits on the body's front edge and whose
-- positive x points at the opponent. The barrel runs forward from inside the body and
-- the grip hangs down from the back of it, which is the whole of the L.
local halfThickness = settings.gunBarrelThickness * 0.5
local gunRearX = -settings.gunOverlap
local gunFrontX = settings.gunBarrelLength - settings.gunOverlap
local gripRightX = gunRearX + settings.gunGripWidth
local gripBottomY = halfThickness + settings.gunGripDrop

-- newPolygon re-centres any vertex list on its own bounding box, so the list is written
-- pre-centred and the shape then lands exactly where it is positioned.
local shapeCenterX = ( gunRearX + gunFrontX ) * 0.5
local shapeCenterY = ( -halfThickness + gripBottomY ) * 0.5

local gunVertices = {
	gunRearX - shapeCenterX, -halfThickness - shapeCenterY,
	gunFrontX - shapeCenterX, -halfThickness - shapeCenterY,
	gunFrontX - shapeCenterX, halfThickness - shapeCenterY,
	gripRightX - shapeCenterX, halfThickness - shapeCenterY,
	gripRightX - shapeCenterX, gripBottomY - shapeCenterY,
	gunRearX - shapeCenterX, gripBottomY - shapeCenterY,
}

-- Distance from the middle of the fighter to the tip of the barrel.
local muzzleOffsetX = settings.bodyWidth * 0.5 + gunFrontX
-- The casing leaves the top of the gun just in front of the body.
local ejectionOffsetX = settings.bodyWidth * 0.5 + settings.gunGripWidth * 0.5

local segmentWidth = ( settings.healthWidth - settings.healthGap * ( fightData.healthSteps - 1 ) ) / fightData.healthSteps
local segmentStep = segmentWidth + settings.healthGap

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, index (1 or 2), x, facing (1 faces right, -1 faces left), color
function fighter.new( params )
	local instance = {}

	instance.index = params.index
	instance.facing = params.facing
	instance.anchorX = params.x
	instance.health = fightData.healthSteps

	instance.shotSound = params.index == 1 and "shotOne" or "shotTwo"
	instance.impactSound = params.index == 1 and "impactOne" or "impactTwo"

	-- The group is what knockback and recoil move, so its x is the fighter's position.
	instance.group = display.newGroup()
	instance.group.x = instance.anchorX
	params.parent:insert( instance.group )

	instance.body = display.newRect( instance.group, 0, bodyCenterY, settings.bodyWidth, settings.bodyHeight )
	instance.body:setFillColor( params.color[1], params.color[2], params.color[3] )

	-- The hit flash is an overlay rather than a fill change, so that fading it back out
	-- is an ordinary alpha transition. It sits under the gun, so a flashing fighter
	-- still visibly holds one.
	instance.flashOverlay = display.newRect( instance.group, 0, bodyCenterY, settings.bodyWidth, settings.bodyHeight )
	instance.flashOverlay:setFillColor( 1 )
	instance.flashOverlay.alpha = 0

	instance.gunAnchorX = ( settings.bodyWidth * 0.5 + shapeCenterX ) * instance.facing
	instance.gunAnchorY = gunCenterY + shapeCenterY
	instance.gun = display.newPolygon( instance.group, instance.gunAnchorX, instance.gunAnchorY, gunVertices )
	instance.gun:setFillColor( palette.gun[1], palette.gun[2], palette.gun[3] )
	-- One vertex list, mirrored for the fighter facing the other way.
	instance.gun.xScale = instance.facing

	instance.healthSegments = {}

	for i = 1, fightData.healthSteps do
		local segmentX = -settings.healthWidth * 0.5 + segmentWidth * 0.5 + ( i - 1 ) * segmentStep
		local segment = display.newRect( instance.group, segmentX, settings.healthY, segmentWidth, settings.healthHeight )
		segment:setFillColor( params.color[1], params.color[2], params.color[3] )

		instance.healthSegments[i] = segment
	end

	instance.color = params.color

	----------------------------------------------------------------------------------

	-- The tip of the barrel, measured from the anchor rather than from the gun's current
	-- position, so that recoil cannot move where the next bullet starts.
	function instance:getMuzzlePosition()
		return self.anchorX + muzzleOffsetX * self.facing, gunCenterY
	end

	function instance:getEjectionPosition()
		return self.anchorX + ejectionOffsetX * self.facing, gunCenterY - halfThickness
	end

	-- Called ahead of the shot, so the fighter can telegraph it.
	function instance:anticipate()
		effects.anticipate( self )
	end

	function instance:fire()
		effects.releaseAnticipation( self )
		effects.recoil( self )

		local muzzleX, muzzleY = self:getMuzzlePosition()
		effects.muzzleFlash( muzzleX, muzzleY )

		local ejectionX, ejectionY = self:getEjectionPosition()
		effects.ejectCasing( ejectionX, ejectionY, self.facing )

		effects.playSound( self.shotSound )
	end

	-- The mechanic, and the only thing a hit is guaranteed to do. This runs at the moment
	-- of contact in every version, including the ones with no feedback at all.
	function instance:registerHit()
		self.health = self.health - 1

		local segment = self.healthSegments[self.health + 1]
		segment:setFillColor( palette.healthEmpty[1], palette.healthEmpty[2], palette.healthEmpty[3] )

		effects.flashStart( self )
		effects.playSound( self.impactSound )
	end

	-- The feedback, which the scene runs once any hit stop has finished.
	function instance:react()
		effects.flashRelease( self )
		effects.knockback( self )
		effects.shake()
	end

	function instance:isDefeated()
		return self.health <= 0
	end

	function instance:reset()
		self.health = fightData.healthSteps

		transition.cancel( self.group )
		transition.cancel( self.body )
		transition.cancel( self.gun )
		transition.cancel( self.flashOverlay )

		self.group.x = self.anchorX
		self.gun.x = self.gunAnchorX
		self.gun.y = self.gunAnchorY
		self.body.xScale = 1
		self.body.yScale = 1
		self.flashOverlay.alpha = 0

		for i = 1, fightData.healthSteps do
			self.healthSegments[i]:setFillColor( self.color[1], self.color[2], self.color[3] )
		end
	end

	function instance:destroy()
		transition.cancel( self.group )
		transition.cancel( self.body )
		transition.cancel( self.gun )
		transition.cancel( self.flashOverlay )

		display.remove( self.group )
		self.group = nil
		self.body = nil
		self.gun = nil
		self.flashOverlay = nil
		self.healthSegments = nil
	end

	return instance
end

--------------------------------------------------------------------------------------

return fighter
