-- Box2D-style contact resolution for the platformer-puzzle tests: the harness stub moves bodies and reports overlaps but
-- resolves no contacts. Translation only (every dynamic body in the sample has fixed rotation), convex polygons and chains,
-- warm-started sequential impulses with Coulomb friction, and Box2D's position correction, with Box2D's constants
-- converted to content units. Install before the sample adds its bodies; step() then replaces stub.step().
-- Usage: local simulation = dofile( "tools/tests/support/platformer-puzzle-physics.lua" ).install( stub )

local puzzlePhysics = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local unitsPerMetre = 30
local frameTime = 1 / 60

-- Box2D rests shapes about 0.45 units apart (a 0.3-unit skin on each, less linearSlop); without skins they rest
-- overlapping by about linearSlop, which the stub's overlap test needs to report a contact.
-- So the solver proves outcomes (pressed, stopped, solved), not distances or thresholds finer than about 5 units.
local skin = 0

-- b2_linearSlop, b2_baumgarte, b2_maxLinearCorrection and b2_velocityThreshold.
local linearSlop = 0.005 * unitsPerMetre
local baumgarte = 0.2
local maxCorrection = 0.2 * unitsPerMetre
local velocityThreshold = 1 * unitsPerMetre

-- Solar2D steps Box2D with 8 velocity and 3 position iterations.
local velocityIterations = 8
local positionIterations = 3

-- Solar2D gives an element without density 0.01, a params table without friction or bounce 0, and no params table 0.3 and 0.5.
local defaultDensity = 0.01
local implicitFriction = 0.3
local implicitBounce = 0.5

local abs, sqrt, min, max = math.abs, math.sqrt, math.min, math.max

--------------------------------------------------------------------------------------
-- Private functions

local function boxPoints( halfWidth, halfHeight, x, y )
	return { x - halfWidth, y - halfHeight, x + halfWidth, y - halfHeight, x + halfWidth, y + halfHeight, x - halfWidth, y + halfHeight }
end

-- Outward unit normals for points clockwise on screen, with y pointing down.
local function newPolygon( points )
	local count = #points / 2
	local normals = {}

	for i = 1, count do
		local nextIndex = i % count + 1
		local edgeX = points[nextIndex * 2 - 1] - points[i * 2 - 1]
		local edgeY = points[nextIndex * 2] - points[i * 2]
		local length = sqrt( edgeX * edgeX + edgeY * edgeY )
		normals[i] = { edgeY / length, -edgeX / length }
	end

	local area = 0

	for i = 1, count do
		local nextIndex = i % count + 1
		area = area + points[i * 2 - 1] * points[nextIndex * 2] - points[nextIndex * 2 - 1] * points[i * 2]
	end

	return { points = points, normals = normals, count = count, area = abs( area ) * 0.5 }
end

-- The largest gap between polygon a's faces and polygon b, and the face it belongs to; negative when they overlap.
local function findMaxSeparation( a, ax, ay, b, bx, by )
	local best, bestIndex = -math.huge, 1

	for i = 1, a.count do
		local normalX, normalY = a.normals[i][1], a.normals[i][2]
		local faceX, faceY = a.points[i * 2 - 1] + ax, a.points[i * 2] + ay
		local nearest = math.huge

		for j = 1, b.count do
			local gap = ( b.points[j * 2 - 1] + bx - faceX ) * normalX + ( b.points[j * 2] + by - faceY ) * normalY
			nearest = min( nearest, gap )
		end

		if nearest > best then
			best, bestIndex = nearest, i
		end
	end

	return best, bestIndex
end

-- Box2D's choice of reference face: b's only when clearly better. Returns the separation (skins included), the normal
-- pointing from a to b, and a key naming the face; nil when the shapes are farther apart than their skins.
local function collide( a, ax, ay, b, bx, by )
	local separationA, faceA = findMaxSeparation( a, ax, ay, b, bx, by )
	if separationA > skin then
		return nil
	end

	local separationB, faceB = findMaxSeparation( b, bx, by, a, ax, ay )
	if separationB > skin then
		return nil
	end

	if separationB > separationA + 0.1 * linearSlop then
		return separationB - skin, -b.normals[faceB][1], -b.normals[faceB][2], "b" .. faceB
	end

	return separationA - skin, a.normals[faceA][1], a.normals[faceA][2], "a" .. faceA
end

local function readElements( object, paramsList )
	local elements = {}

	for i = 1, #paramsList do
		local params = paramsList[i]
		local shapes = {}

		if params.shape then
			local points = {}
			for j = 1, #params.shape do
				points[j] = params.shape[j]
			end
			shapes[1] = points

		elseif params.box then
			local box = params.box
			shapes[1] = boxPoints( box.halfWidth, box.halfHeight, box.x or 0, box.y or 0 )

		elseif params.chain then
			-- A chain collides along its edges, so each edge is simulated as a two-point polygon.
			local chain = params.chain
			local count = #chain / 2
			local lastIndex = params.connectFirstAndLastChainVertex and count or count - 1

			for j = 1, lastIndex do
				local nextIndex = j % count + 1
				shapes[j] = { chain[j * 2 - 1], chain[j * 2], chain[nextIndex * 2 - 1], chain[nextIndex * 2] }
			end

		elseif params.radius or params.outline then
			error( "puzzle physics: only boxes, polygons and chains are simulated" )

		else
			shapes[1] = boxPoints( object.width * 0.5, object.height * 0.5, 0, 0 )
		end

		local density = ( params.density and params.density > 0 ) and params.density or defaultDensity

		for j = 1, #shapes do
			elements[#elements + 1] = {
				polygon = newPolygon( shapes[j] ),
				friction = params.friction or 0,
				bounce = params.bounce or 0,
				isSensor = params.isSensor == true,
				density = density,
			}
		end
	end

	if #paramsList == 0 then
		elements[1] = {
			polygon = newPolygon( boxPoints( object.width * 0.5, object.height * 0.5, 0, 0 ) ),
			friction = implicitFriction,
			bounce = implicitBounce,
			isSensor = false,
			density = defaultDensity,
		}
	end

	return elements
end

--------------------------------------------------------------------------------------
-- Public functions

function puzzlePhysics.install( stub )
	local physics = require( "physics" )

	local simulation = {}
	local bodies = {}
	local nextElementId = 0
	local cachedImpulses = {}

	local addBody = physics.addBody
	physics.addBody = function( object, ... )
		local result = addBody( object, ... )

		local paramsList = {}
		local bodyType = "dynamic"
		local arguments = { ... }

		for i = 1, select( "#", ... ) do
			if type( arguments[i] ) == "string" then
				bodyType = arguments[i]

			elseif type( arguments[i] ) == "table" then
				paramsList[#paramsList + 1] = arguments[i]
			end
		end

		local elements = readElements( object, paramsList )
		local mass = 0

		for i = 1, #elements do
			nextElementId = nextElementId + 1
			elements[i].id = nextElementId
			mass = mass + elements[i].density * elements[i].polygon.area / ( unitsPerMetre * unitsPerMetre )
		end

		-- The stub counts sensors at density 1; Box2D's mass makes jump impulses lift the player as high as in Solar2D.
		if bodyType == "dynamic" then
			rawset( object, "mass", mass )
		end

		bodies[#bodies + 1] = { object = object, elements = elements, isDynamic = bodyType == "dynamic", mass = mass }

		return result
	end

	local function hasBody( object )
		local internal = rawget( object, "_stub" )
		return stub.isAlive( object ) and internal ~= nil and internal.body ~= nil
	end

	local function liveBodies()
		local live = {}

		for i = #bodies, 1, -1 do
			if not hasBody( bodies[i].object ) then
				table.remove( bodies, i )
			end
		end

		for i = 1, #bodies do
			if bodies[i].object.isBodyActive then
				live[#live + 1] = bodies[i]
			end
		end

		return live
	end

	local function findContacts( live )
		local contacts = {}

		for i = 1, #live do
			local bodyA = live[i]

			for j = 1, #live do
				local bodyB = live[j]
				local isPairOwner = bodyA.isDynamic and ( not bodyB.isDynamic or j > i )

				if i ~= j and isPairOwner then
					for a = 1, #bodyA.elements do
						local elementA = bodyA.elements[a]

						for b = 1, #bodyB.elements do
							local elementB = bodyB.elements[b]

							if not elementA.isSensor and not elementB.isSensor then
								local separation, normalX, normalY, face = collide(
									elementA.polygon, bodyA.object.x, bodyA.object.y, elementB.polygon, bodyB.object.x, bodyB.object.y
								)

								if separation then
									contacts[#contacts + 1] = {
										bodyA = bodyA,
										bodyB = bodyB,
										elementA = elementA,
										elementB = elementB,
										normalX = normalX,
										normalY = normalY,
										key = elementA.id .. ":" .. elementB.id .. ":" .. face,
										friction = sqrt( elementA.friction * elementB.friction ),
										bounce = max( elementA.bounce, elementB.bounce ),
									}
								end
							end
						end
					end
				end
			end
		end

		return contacts
	end

	local function inverseMass( body )
		return body.isDynamic and 1 / body.mass or 0
	end

	-- Impulses are in kilogram content units per second; velocities in content units per second.
	local function applyImpulse( contact, impulseX, impulseY, velocities )
		local velocityA = velocities[contact.bodyA]
		local velocityB = velocities[contact.bodyB]
		velocityA[1] = velocityA[1] - impulseX * contact.inverseMassA
		velocityA[2] = velocityA[2] - impulseY * contact.inverseMassA

		if velocityB then
			velocityB[1] = velocityB[1] + impulseX * contact.inverseMassB
			velocityB[2] = velocityB[2] + impulseY * contact.inverseMassB
		end
	end

	local function relativeVelocity( contact, velocities )
		local velocityA = velocities[contact.bodyA]
		local velocityB = velocities[contact.bodyB] or { 0, 0 }

		return velocityB[1] - velocityA[1], velocityB[2] - velocityA[2]
	end

	local function solveVelocities( contacts, velocities )
		local nextCache = {}

		for i = 1, #contacts do
			local contact = contacts[i]
			contact.inverseMassA = inverseMass( contact.bodyA )
			contact.inverseMassB = inverseMass( contact.bodyB )
			contact.mass = 1 / ( contact.inverseMassA + contact.inverseMassB )
			contact.tangentX, contact.tangentY = -contact.normalY, contact.normalX

			local relativeX, relativeY = relativeVelocity( contact, velocities )
			local approach = relativeX * contact.normalX + relativeY * contact.normalY
			contact.bias = approach < -velocityThreshold and -contact.bounce * approach or 0

			local cached = cachedImpulses[contact.key]
			contact.normalImpulse = cached and cached[1] or 0
			contact.tangentImpulse = cached and cached[2] or 0

			applyImpulse( contact,
				contact.normalX * contact.normalImpulse + contact.tangentX * contact.tangentImpulse,
				contact.normalY * contact.normalImpulse + contact.tangentY * contact.tangentImpulse,
				velocities )
		end

		for _ = 1, velocityIterations do
			for i = 1, #contacts do
				local contact = contacts[i]

				local relativeX, relativeY = relativeVelocity( contact, velocities )
				local slide = relativeX * contact.tangentX + relativeY * contact.tangentY
				local limit = contact.friction * contact.normalImpulse
				local tangentImpulse = max( -limit, min( limit, contact.tangentImpulse - contact.mass * slide ) )
				local change = tangentImpulse - contact.tangentImpulse
				contact.tangentImpulse = tangentImpulse
				applyImpulse( contact, contact.tangentX * change, contact.tangentY * change, velocities )

				relativeX, relativeY = relativeVelocity( contact, velocities )
				local approach = relativeX * contact.normalX + relativeY * contact.normalY
				local normalImpulse = max( 0, contact.normalImpulse - contact.mass * ( approach - contact.bias ) )
				change = normalImpulse - contact.normalImpulse
				contact.normalImpulse = normalImpulse
				applyImpulse( contact, contact.normalX * change, contact.normalY * change, velocities )
			end
		end

		for i = 1, #contacts do
			nextCache[contacts[i].key] = { contacts[i].normalImpulse, contacts[i].tangentImpulse }
		end

		cachedImpulses = nextCache
	end

	local function solvePositions( contacts )
		for _ = 1, positionIterations do
			for i = 1, #contacts do
				local contact = contacts[i]
				local bodyA, bodyB = contact.bodyA, contact.bodyB
				local objectA, objectB = bodyA.object, bodyB.object

				local separation, normalX, normalY = collide( contact.elementA.polygon, objectA.x, objectA.y, contact.elementB.polygon, objectB.x, objectB.y )

				if separation then
					local correction = max( -maxCorrection, min( 0, baumgarte * ( separation + linearSlop ) ) )
					local impulse = -correction * contact.mass

					objectA.x = objectA.x - normalX * impulse * contact.inverseMassA
					objectA.y = objectA.y - normalY * impulse * contact.inverseMassA

					if bodyB.isDynamic then
						objectB.x = objectB.x + normalX * impulse * contact.inverseMassB
						objectB.y = objectB.y + normalY * impulse * contact.inverseMassB
					end
				end
			end
		end
	end

	-- One frame: the stub's step (gravity, overlap events, enterFrame), then Box2D's order of contact solving from the
	-- positions the frame started at: velocities, then positions moved by them, then overlap correction.
	function simulation.step()
		local live = liveBodies()
		local starts = {}

		for i = 1, #live do
			if live[i].isDynamic then
				starts[live[i]] = { live[i].object.x, live[i].object.y }
			end
		end

		stub.step()

		if stub.physicsState() ~= "running" then
			return
		end

		local moved = {}
		local velocities = {}

		for body, start in pairs( starts ) do
			if hasBody( body.object ) and body.object.isBodyActive then
				moved[#moved + 1] = body
				body.object.x, body.object.y = start[1], start[2]

				local vx, vy = body.object:getLinearVelocity()
				velocities[body] = { vx, vy }
			end
		end

		local contacts = findContacts( liveBodies() )

		-- Bodies added during this frame's enterFrame have no start position and stay out until the next frame.
		for i = #contacts, 1, -1 do
			if not velocities[contacts[i].bodyA] or ( contacts[i].bodyB.isDynamic and not velocities[contacts[i].bodyB] ) then
				table.remove( contacts, i )
			end
		end

		solveVelocities( contacts, velocities )

		for i = 1, #moved do
			local body = moved[i]
			local velocity = velocities[body]
			body.object:setLinearVelocity( velocity[1], velocity[2] )
			body.object.x = body.object.x + velocity[1] * frameTime
			body.object.y = body.object.y + velocity[2] * frameTime
		end

		solvePositions( contacts )
	end

	function simulation.steps( count )
		for _ = 1, count do
			simulation.step()
		end
	end

	return simulation
end

return puzzlePhysics
