-- Keyboard actions from one Runtime key listener, as held keys.

local input = {}

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

		for i = 1, #keyNames do
			if heldKeys[keyNames[i]] then
				return true
			end
		end

		return false
	end

	-- Returns 1 or -1 while only one of the two actions is held, otherwise 0.
	function controls:getAxis( negativeAction, positiveAction )
		local axis = 0

		if self:isHeld( negativeAction ) then
			axis = axis - 1
		end

		if self:isHeld( positiveAction ) then
			axis = axis + 1
		end

		return axis
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
