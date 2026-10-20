local controls = {}

local callbackMovement = nil
local callbackKey = nil

local hasStarted = false
local isPressed = {}

local loadsave = require( "scripts.loadsave" )
local key = {}

for action, keyName in pairs( loadsave.userdata.controls ) do
	for i = 1, #keyName do
		key[keyName[i]] = action
	end
end


local function monitorMovement()
	local vx, vy = 0, 0

	if isPressed["left"] then vx = vx - 1 end
	if isPressed["right"] then vx = vx + 1 end
	if isPressed["up"] then vy = vy - 1 end
	if isPressed["down"] then vy = vy + 1 end

	callbackMovement( vx, vy )
end


local function onKeyEvent( event )
	local action = key[event.keyName]
	-- print( event.phase, event.keyName, action )

	if action then
		isPressed[action] = (event.phase == "down")

		callbackKey( action, event.phase )
	end
end


function controls.start( listenerMovement, listenerKey )
	if not hasStarted then
		hasStarted = true

		callbackMovement = listenerMovement
		callbackKey = listenerKey

		Runtime:addEventListener( "enterFrame", monitorMovement )
		Runtime:addEventListener( "key", onKeyEvent )
	end
end


function controls.stop()
	if hasStarted then
		hasStarted = false

		Runtime:removeEventListener( "enterFrame", monitorMovement )
		Runtime:removeEventListener( "key", onKeyEvent )

		for action, _ in pairs( isPressed ) do
			isPressed[action] = false
		end
	end
end

return controls