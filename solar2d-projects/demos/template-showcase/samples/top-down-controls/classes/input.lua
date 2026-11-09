-- Keyboard actions from one Runtime key listener: held keys, a movement vector and the latest pressed direction.

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

-- bindings maps each action to its key names; onPress( action ) runs when any bound key goes down.
function input.new( bindings, onPress )
	local controls = {}

	local actionForKey = {}
	for action, keyNames in pairs( bindings ) do
		for i = 1, #keyNames do
			actionForKey[keyNames[i]] = action
		end
	end

	local heldKeys = {}
	local isStarted = false

	-- Each press gets a higher number, so the newest held direction wins.
	local pressCount = 0
	local pressOrder = {}

	-- The latest direction pressed, kept until taken so a quick tap is never missed.
	local pressedDirection = nil

	local function onKey( event )
		local action = actionForKey[event.keyName]
		if not action then
			return false
		end

		local isDown = event.phase == "down"

		-- Some platforms repeat "down" events while a key is held; only the first one is a press.
		if isDown and heldKeys[event.keyName] then
			return true
		end

		heldKeys[event.keyName] = isDown

		if isDown then
			pressCount = pressCount + 1
			pressOrder[action] = pressCount

			if directions[action] then
				pressedDirection = action
			end

			if onPress then
				onPress( action )
			end
		end

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

	-- Returns the most recently pressed direction that is still held, or 0, 0.
	function controls:getHeldDirection()
		local latest = nil

		for action in pairs( directions ) do
			if self:isHeld( action ) and ( not latest or pressOrder[action] > pressOrder[latest] ) then
				latest = action
			end
		end

		if not latest then
			return 0, 0
		end

		return directions[latest][1], directions[latest][2]
	end

	-- Returns the latest direction pressed since the last call, held or not, or 0, 0.
	function controls:takePressedDirection()
		local action = pressedDirection
		pressedDirection = nil

		if not action then
			return 0, 0
		end

		return directions[action][1], directions[action][2]
	end

	function controls:clearPressed()
		pressedDirection = nil
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
		pressedDirection = nil
	end

	return controls
end

return input
