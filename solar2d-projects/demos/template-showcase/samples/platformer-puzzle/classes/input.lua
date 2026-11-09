local input = {}

--------------------------------------------------------------------------------------
-- Public functions

-- bindings maps each action (left, right, jump and any others) to its key names.
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

	-- Each press gets a higher number, so the newer of left and right wins while both are held.
	local pressCount = 0
	local pressOrder = {}

	-- Actions pressed since they were last taken, so a quick tap is never missed.
	local pressed = {}

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
			pressed[action] = true
		end

		return true
	end

	function controls:isHeld( action )
		local keyNames = bindings[action]
		for i = 1, #keyNames do
			if heldKeys[keyNames[i]] then
				return true
			end
		end

		return false
	end

	-- Returns -1 for left, 1 for right or 0 for neither.
	function controls:getRunDirection()
		local isLeft = self:isHeld( "left" )
		local isRight = self:isHeld( "right" )

		if isLeft and isRight then
			return pressOrder.left > pressOrder.right and -1 or 1

		elseif isLeft then
			return -1

		elseif isRight then
			return 1
		end

		return 0
	end

	-- Returns true once for each press of the action, whether or not the key is still held.
	function controls:takePress( action )
		local wasPressed = pressed[action] == true
		pressed[action] = nil

		return wasPressed
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
		pressed = {}
	end

	return controls
end

return input
