-- Melee enemies chase the hero and swing a sword; ranged enemies keep their distance and shoot arrows.

local enemy = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

local combat = require( "samples.top-down-combat.classes.combat" )

--------------------------------------------------------------------------------------
-- Localised functions

local max = math.max
local min = math.min
local sqrt = math.sqrt

--------------------------------------------------------------------------------------
-- Private functions

-- The ray runs in the world group's coordinates, which is where every body lives.
local function hasLineOfSight( fromX, fromY, toX, toY )
	local hits = physics.rayCast( fromX, fromY, toX, toY, "unsorted" )
	if hits then
		for i = 1, #hits do
			if hits[i].object.kind == "wall" then
				return false
			end
		end
	end

	return true
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, x, y, role ("melee" or "ranged"), config (settings.enemies[role]), filter, body, target (the hero),
-- projectiles, reaction, flashColor, and the callbacks onAttack( role ), onHit() and onDeath( foe ).
function enemy.new( params )
	local config = params.config
	local target = params.target

	local foe = combat.newFighter({
		parent = params.parent,
		x = params.x,
		y = params.y,
		kind = "enemy",
		filter = params.filter,
		body = params.body,
		config = config,
	})

	foe.hp = config.hp

	local cooldownLeft = config.attackCooldown

	local isSwinging = false
	local swingTime = 0
	local swingHeading = 0
	local hasStruck = false

	-- Quick and dirty fix: the sword shows only during the attack, so walking enemies do not look like they are already stabbing.
	local function setSwordShown( isShown )
		foe.weaponPivot.isVisible = isShown or params.role ~= "melee"
	end

	setSwordShown( false )

	local function endSwing()
		isSwinging = false
		setSwordShown( false )
	end

	local function move( heading, speed )
		local directionX, directionY = combat.direction( heading )
		foe:setLinearVelocity( directionX * speed, directionY * speed )
	end

	-- The sword rises to one edge of the arc, then sweeps to the other; the hero is checked once mid-sweep.
	local function updateSwing( deltaTime )
		local swing = config.swing
		swingTime = swingTime + deltaTime

		if swingTime < swing.windupTime then
			foe.weaponPivot.rotation = swingHeading - swing.halfArc * swingTime / swing.windupTime
			return
		end

		local progress = min( 1, ( swingTime - swing.windupTime ) / swing.sweepTime )
		foe.weaponPivot.rotation = swingHeading - swing.halfArc + 2 * swing.halfArc * progress

		if not hasStruck and progress >= swing.strikeAt then
			hasStruck = true

			if combat.isInArc( foe.x, foe.y, swingHeading, swing.halfArc, swing.reach, target.x, target.y ) then
				target:takeHit( config.damage, foe.x, foe.y )
			end
		end

		if progress >= 1 then
			endSwing()
			cooldownLeft = config.attackCooldown
		end
	end

	local function updateMelee( heading, distance )
		if distance > config.swing.startDistance then
			move( heading, config.speed )

		elseif cooldownLeft <= 0 then
			isSwinging = true
			swingTime = 0
			swingHeading = heading
			hasStruck = false
			setSwordShown( true )
			params.onAttack( params.role )
		end
	end

	local function updateRanged( heading, distance )
		if distance > config.keepDistance + config.distanceSlack then
			move( heading, config.speed )

		elseif distance < config.keepDistance - config.distanceSlack then
			move( heading + 180, config.speed )
		end

		if cooldownLeft <= 0 and distance <= config.shotRange and hasLineOfSight( foe.x, foe.y, target.x, target.y ) then
			cooldownLeft = config.attackCooldown
			params.projectiles:fire( "enemy", foe.x, foe.y, heading )
			params.onAttack( params.role )
		end
	end

	-- deltaTime is in milliseconds.
	function foe:update( deltaTime )
		if combat.updateReaction( self, deltaTime, params.flashColor ) then
			return
		end

		self:setLinearVelocity( 0, 0 )

		if isSwinging then
			updateSwing( deltaTime )
			return
		end

		if target.hp <= 0 then
			return
		end

		cooldownLeft = max( 0, cooldownLeft - deltaTime )

		local heading = combat.headingTo( self.x, self.y, target.x, target.y )
		local distance = sqrt( combat.distanceSquared( self.x, self.y, target.x, target.y ) )
		self:face( heading )

		-- Idea: add more enemy types with their own stats and behaviour, such as a boss with phases.
		if params.role == "melee" then
			updateMelee( heading, distance )
		else
			updateRanged( heading, distance )
		end
	end

	-- A hit interrupts a swing, so landing arrows on a melee enemy buys time.
	function foe:takeHit( damage, fromX, fromY )
		if self.hp <= 0 then
			return
		end

		self.hp = self.hp - damage
		endSwing()
		cooldownLeft = max( cooldownLeft, config.attackCooldown )
		combat.hit( self, fromX, fromY, params.reaction )

		if self.hp <= 0 then
			-- Idea: drop a heart or a coin here that the hero can pick up.
			params.onDeath( self )
		else
			params.onHit()
		end
	end

	-- Ends a swing in progress, so a hidden scene never keeps a sword raised.
	function foe:stopAttack()
		endSwing()
	end

	return foe
end

return enemy
