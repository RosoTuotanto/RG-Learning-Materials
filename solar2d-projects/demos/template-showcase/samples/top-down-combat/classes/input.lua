-- Held keys from one Runtime key listener, read as a movement vector.

local input = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local directions = {
	up = { 0, -1 },
	down = { 0, 1 },
	left = { -1, 0 },
	right = { 1, 0 },
}

--------------------------------------------------------------------------------------
-- Localised functions

local sqrt = math.sqrt

--------------------------------------------------------------------------------------
-- Public functions

-- bindings maps each action to its key names.
function input.new( bindings )
	local controls = {}

	local actionForKey = {}
	for action, keyNames in pairs( bindings ) do
		for i = 1, #keyNames do
			actionForKey[keyNames[i]] = action
		end
	end

	local heldKeys = {}
	local isStarted = false

	local function onKey( event )
		if not actionForKey[event.keyName] then
			return false
		end

		heldKeys[event.keyName] = event.phase == "down"

		return true
	end

	function controls:isHeld( action )
		local keyNames = bindings[action]
		if not keyNames then
			return false
		end

		for i = 1, #keyNames do
			if heldKeys[keyNames[i]] then
				return true
			end
		end

		return false
	end

	-- Returns the movement vector, scaled to length 1 so diagonals are not faster.
	function controls:getMovement()
		local x, y = 0, 0

		for action, direction in pairs( directions ) do
			if self:isHeld( action ) then
				x = x + direction[1]
				y = y + direction[2]
			end
		end

		local length = sqrt( x * x + y * y )
		if length > 0 then
			x = x / length
			y = y / length
		end

		return x, y
	end

	function controls:start()
		if not isStarted then
			isStarted = true
			Runtime:addEventListener( "key", onKey )
		end
	end

	-- Stops listening and forgets every held key, so nothing stays pressed after the scene leaves.
	function controls:stop()
		if isStarted then
			isStarted = false
			Runtime:removeEventListener( "key", onKey )
		end

		heldKeys = {}
	end

	return controls
end

return input
