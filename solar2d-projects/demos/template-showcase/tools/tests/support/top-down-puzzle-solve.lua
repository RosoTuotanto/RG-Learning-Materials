-- Breadth-first search over room states with the sample's own rules; prints the shortest move list per room.
package.path = "./?.lua;" .. package.path

local puzzle = require( "samples.top-down-puzzle.classes.puzzle" )
local roomData = require( "samples.top-down-puzzle.data.rooms" )

local moves = { U = { 0, -1 }, D = { 0, 1 }, L = { -1, 0 }, R = { 1, 0 } }
local order = { "U", "D", "L", "R" }

local function stateKey( room )
	local parts = {}
	for i = 1, #room.crates do
		parts[i] = room.crates[i].column .. "," .. room.crates[i].row
	end
	table.sort( parts )
	return room.hero.column .. "," .. room.hero.row .. "|" .. table.concat( parts, ";" )
end

local function replay( room, path )
	room:restart()
	for i = 1, #path do
		local move = moves[path:sub( i, i )]
		room:move( move[1], move[2] )
	end
end

for index = 1, #roomData.rooms do
	local room = puzzle.new( roomData.rooms[index], roomData.symbols )
	local seen = { [stateKey( room )] = true }
	local queue = { "" }
	local head = 1
	local found = nil

	while head <= #queue and not found do
		local path = queue[head]
		head = head + 1

		for i = 1, #order do
			replay( room, path )
			local move = moves[order[i]]
			if room:move( move[1], move[2] ) then
				local nextPath = path .. order[i]
				if room:isExited() then
					found = nextPath
					break
				end

				local key = stateKey( room )
				if not seen[key] then
					seen[key] = true
					queue[#queue + 1] = nextPath
				end
			end
		end
	end

	print( "room " .. index .. ": " .. ( found or "UNSOLVABLE" ) .. " (" .. ( found and #found or 0 ) .. " moves, " .. #queue .. " states)" )
end
