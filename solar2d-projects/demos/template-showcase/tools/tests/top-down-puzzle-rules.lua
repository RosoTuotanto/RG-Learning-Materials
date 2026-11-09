-- Headless checks of the puzzle rules and a scripted solution for every room. Prints failures and a count.
package.path = "./?.lua;" .. package.path

local puzzle = require( "samples.top-down-puzzle.classes.puzzle" )
local roomData = require( "samples.top-down-puzzle.data.rooms" )

local symbols = roomData.symbols
local moves = { U = { 0, -1 }, D = { 0, 1 }, L = { -1, 0 }, R = { 1, 0 } }

local checkCount = 0
local failureCount = 0

local function check( condition, label )
	checkCount = checkCount + 1
	if not condition then
		failureCount = failureCount + 1
		print( "FAIL " .. label )
	end
end

local function play( room, path )
	local lastStep
	for i = 1, #path do
		local move = moves[path:sub( i, i )]
		lastStep = room:move( move[1], move[2] )
	end
	return lastStep
end

local function at( position, column, row )
	return position.column == column and position.row == row
end

-- Pushing, walls and chained crates.
local room = puzzle.new( { "#######", "#S.C..#", "#..CC.#", "#.....#", "#######" }, symbols )
check( room:move( -1, 0 ) == nil, "wall blocks the hero" )
check( room:getMoveCount() == 0, "blocked move is not counted" )
local step = play( room, "R" )
check( step and not step.crateIndex and at( room.hero, 3, 2 ), "plain step" )
step = play( room, "R" )
check( step and step.crateIndex == 1 and at( room.crates[1], 5, 2 ) and at( room.hero, 4, 2 ), "push onto floor" )
check( play( room, "R" ) and at( room.crates[1], 6, 2 ), "second push" )
check( play( room, "R" ) == nil and at( room.hero, 5, 2 ) and at( room.crates[1], 6, 2 ), "crate against wall blocks" )
room:restart()
check( at( room.hero, 2, 2 ) and at( room.crates[1], 4, 2 ) and room:getMoveCount() == 0, "restart resets hero, crates and moves" )
check( play( room, "DRR" ) == nil and at( room.hero, 3, 3 ) and at( room.crates[2], 4, 3 ) and at( room.crates[3], 5, 3 ), "two crates in a row block" )

-- Plates and the door.
room = puzzle.new( { "###D###", "#.....#", "#S.CP.#", "#..C.P#", "#.....#", "#######" }, symbols )
check( not room:isDoorOpen(), "door starts closed" )
check( play( room, "R" ) and play( room, "R" ) and at( room.crates[1], 5, 3 ), "crate pushed onto plate" )
check( not room:isDoorOpen(), "one of two plates keeps the door closed" )
play( room, "U" )
check( at( room.hero, 4, 2 ) and play( room, "U" ) == nil, "closed door blocks the hero" )
room:restart()
play( room, "RRLDRR" )
check( at( room.crates[2], 6, 4 ) and room:isDoorOpen(), "both plates covered opens the door" )
local beforeUndo = room:getMoveCount()
check( room:undo() and not room:isDoorOpen() and at( room.crates[2], 5, 4 ) and at( room.hero, 4, 4 ),
	"undo pulls the crate off the plate and closes the door" )
check( room:getMoveCount() == beforeUndo - 1, "undo lowers the move count" )
play( room, "R" )
check( room:isDoorOpen(), "redo opens the door again" )
play( room, "U" )
check( at( room.crates[1], 5, 2 ) and not room:isDoorOpen(), "crate pushed off a plate closes the door" )
room:undo()
check( room:isDoorOpen() and at( room.crates[1], 5, 3 ), "undo puts the crate back on the plate" )
while room:undo() do
end
check( room:getMoveCount() == 0 and at( room.hero, 2, 3 ) and at( room.crates[1], 4, 3 ) and at( room.crates[2], 4, 4 ), "undo all the way back to the start" )
check( room:undo() == false, "undo at the start does nothing" )

-- Crates never go into a door, open or closed.
room = puzzle.new( { "##D##", "#.C.#", "#.S.#", "#####" }, symbols )
check( play( room, "U" ) == nil and at( room.crates[1], 3, 2 ), "crate cannot be pushed into the door" )

-- Every room is solvable; the scripted lists come from tools/tests/support/top-down-puzzle-solve.lua.
local solutions = {
	"UURRRUURU",
	"URUURRRRRULULDDLLUUU",
	"RURURRRRRUULDDUUULLDLLDLLUURDLDDRRUURURU",
}

check( #solutions == #roomData.rooms, "one solution per room" )
for index = 1, #roomData.rooms do
	room = puzzle.new( roomData.rooms[index], roomData.symbols )
	check( not room:isDoorOpen(), "room " .. index .. " door starts closed" )
	play( room, solutions[index]:sub( 1, -2 ) )
	check( room:isDoorOpen() and not room:isExited(), "room " .. index .. " door open before the last move" )
	check( play( room, solutions[index]:sub( -1 ) ) and room:isExited(), "room " .. index .. " solved by its scripted moves" )
	check( room:getMoveCount() == #solutions[index], "room " .. index .. " counts every move" )
end

print( checkCount .. " checks, " .. failureCount .. " failures" )
os.exit( failureCount == 0 and 0 or 1 )
