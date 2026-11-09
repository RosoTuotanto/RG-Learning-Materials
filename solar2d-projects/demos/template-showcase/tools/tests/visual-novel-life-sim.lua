-- Two seven-day play-throughs of visual-novel-life-sim under the Solar2D stub: one pays the rent, one does not.
-- Usage, from the demo root: lua5.1 tools/tests/visual-novel-life-sim.lua
local lfs = require( "lfs" )

local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. package.path

local failures, checks = 0, 0

local function check( condition, message )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. message )
	end
end

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/visual-novel-life-sim" )

local function steps( count )
	for _ = 1, count do
		stub.step()
	end
end

local function press( keyName )
	stub.call( stub.key, keyName, "down", false )
	steps( 1 )
	stub.call( stub.key, keyName, "up", false )
	steps( 1 )
end

local function click( x, y )
	stub.call( stub.touchAt, x, y, "began" )
	stub.call( stub.touchAt, x, y, "ended" )
	steps( 1 )
end

local function each( group, visit )
	for i = 1, ( group.numChildren or 0 ) do
		local child = group[i]
		visit( child )
		each( child, visit )
	end
end

local function isShown( object )
	while object do
		if not object.isVisible then
			return false
		end
		object = object.parent
	end
	return true
end

-- Remembers each image's file, so a preview icon can be traced back to its stat.
local newImageRect = display.newImageRect
display.newImageRect = function( ... )
	local image = newImageRect( ... )
	local args = { ... }
	for i = 1, #args do
		if type( args[i] ) == "string" then
			image.testFilename = args[i]
			break
		end
	end
	return image
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.visual-novel-life-sim.demo" )
local settings = require( "samples.visual-novel-life-sim.data.settings" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
steps( 2 )

local view = scene.view

local function screenText()
	local parts = {}
	each( view, function( object )
		if type( object.text ) == "string" and object.text ~= "" and isShown( object ) then
			parts[#parts + 1] = object.text
		end
	end )
	return table.concat( parts, " | " )
end

local function shows( text )
	return string.find( screenText(), text, 1, true ) ~= nil
end

local function findText( pattern )
	local found
	each( view, function( object )
		if not found and type( object.text ) == "string" and string.find( object.text, pattern ) then
			found = object
		end
	end )
	return found
end

-- Bible numbers, written out independently of story.json.
local effects = {
	CaseWatchTill = { money = 15, health = -10, happiness = -5, secretary = 5 },
	CaseAsk = { money = 5, social = 5, secretary = -5 },
	MaeDrink = { happiness = 10, health = -5, money = -5, mae = 5 },
	MaeNews = { money = -10, social = 10, mae = 10 },
	RestSleep = { health = 15, happiness = 5, secretary = -5 },
	RestNap = { health = 5, money = 5 },
	PrecinctTell = { social = 5, briggs = 15, jimmy = -20 },
	PrecinctKeep = { happiness = 5, briggs = -10 },
	CallVivian = { money = 15, happiness = 5, vivian = 10 },
	CallJimmy = { social = 10, jimmy = 15, briggs = -5 },
}

-- choice passage by action index and choice index
local choicePassages = {
	{ "CaseWatchTill", "CaseAsk" },
	{ "MaeDrink", "MaeNews" },
	{ "RestSleep", "RestNap" },
	{ "PrecinctTell", "PrecinctKeep" },
	{ "CallVivian", "CallJimmy" },
}

local statIds = { "money", "health", "happiness", "social" }
local relationIds = { "secretary", "briggs", "jimmy", "mae", "vivian" }
local relationNames = { secretary = "Secretary", briggs = "Commissioner Briggs", jimmy = "Slippin' Jimmy", mae = "Mae", vivian = "Vivian Ash" }
local isStat = { money = true, health = true, happiness = true, social = true }

local model
local clampsHit
local clampedPreviews = 0

local function resetModel()
	model = { money = 20, health = 70, happiness = 40, social = 30, secretary = 30, briggs = 0, jimmy = 10, mae = 20, vivian = 0 }
end

-- What a passage's bible numbers change from the model, inside the limits; zero changes are left out, as a preview leaves them out.
local function projectBible( passageName, recordClamps )
	local changes = {}

	for id, amount in pairs( effects[passageName] ) do
		local low, high = 0, 100
		if not isStat[id] then
			low = -100
		end

		local raw = model[id] + amount
		local change = math.min( math.max( raw, low ), high ) - model[id]
		if change ~= 0 then
			changes[id] = change
		end

		if recordClamps and raw > high then
			clampsHit[id .. " top"] = true
		elseif recordClamps and raw < low then
			clampsHit[id .. " bottom"] = true
		end
	end
	return changes
end

local function applyModel( changes )
	for id, amount in pairs( changes ) do
		model[id] = model[id] + amount
	end
end

-- Each stat row in the HUD is icon, track, fill, value and change, after the panel and the day text.
local function statRow( index )
	local hud = findText( "^Day %d+ of %d+$" ).parent
	local first = 3 + ( index - 1 ) * 5
	return { fill = hud[first + 2], value = hud[first + 3], change = hud[first + 4] }
end

local function statBar( index )
	return statRow( index ).fill
end

local function signed( amount )
	return amount == 0 and "" or string.format( "%+d", amount )
end

local statByIcon, relationByName = {}, {}
for i = 1, #settings.stats do
	statByIcon[settings.imageFolder .. settings.stats[i].icon] = settings.stats[i].id
end
for i = 1, #settings.relationships do
	relationByName[settings.relationships[i].shortName] = settings.relationships[i].id
end

-- Reads the changes an option button draws under its label, as { [id] = amount }, and whether it drew a row at all.
local function readPreview( button, label )
	local row
	for i = 1, button.numChildren do
		if button[i].numChildren then
			row = button[i]
		end
	end

	local preview = {}
	if not row then
		return preview, false
	end

	local pendingId
	for i = 1, row.numChildren do
		local child = row[i]

		if child.testFilename then
			pendingId = statByIcon[child.testFilename]
			check( pendingId ~= nil, label .. ": preview icon " .. tostring( child.testFilename ) .. " is a stat icon" )

		elseif relationByName[child.text] then
			pendingId = relationByName[child.text]

		else
			local amount = tonumber( child.text )
			local isSignedAmount = amount ~= nil and child.text == signed( amount )
			check( pendingId ~= nil and isSignedAmount, label .. ": preview text \"" .. tostring( child.text ) .. "\" follows an icon or a name and is signed" )
			if pendingId and amount then
				preview[pendingId] = ( preview[pendingId] or 0 ) + amount
			end
			pendingId = nil
		end
	end

	local bounds = stub.contentBounds( row )
	check( bounds.xMax - bounds.xMin <= button.box.width - 16, label .. ": preview fits on its button" )
	check( math.abs( ( bounds.xMin + bounds.xMax ) * 0.5 - button.x ) < 1, label .. ": preview is centred" )
	return preview, true
end

local function samePreview( preview, expected )
	for id, amount in pairs( preview ) do
		if expected[id] ~= amount then
			return false
		end
	end
	for id, amount in pairs( expected ) do
		if preview[id] ~= amount then
			return false
		end
	end
	return true
end

local function describe( preview )
	local parts = {}
	for id, amount in pairs( preview ) do
		parts[#parts + 1] = id .. signed( amount )
	end
	table.sort( parts )
	return "{" .. table.concat( parts, " " ) .. "}"
end

-- The story's choice buttons on screen, in order.
local function choiceButtons()
	local buttons = {}
	each( view, function( object )
		if type( object.target ) == "string" and object.index and isShown( object ) then
			buttons[object.index] = object
		end
	end )
	return buttons
end

local function actionRows()
	local rows = {}
	each( view, function( object )
		if object.menu and object.index then
			rows[object.index] = object
		end
	end )
	return rows
end

local hudLayout = settings.hud
local hudButtonX = hudLayout.x + hudLayout.width * 0.5
local hudButtonY = hudLayout.y + hudLayout.buttonOffset
local panelLayout = settings.relationshipsPanel
local closeX = panelLayout.x + panelLayout.width * 0.5 - panelLayout.closeInset - panelLayout.closeWidth * 0.5
local closeY = panelLayout.y - panelLayout.height * 0.5 + panelLayout.titleOffset

local function panelShown()
	local shown = false
	each( view, function( object )
		if object.text == panelLayout.title and object.parent.numChildren > 20 then
			shown = isShown( object )
		end
	end )
	return shown
end

local function checkStats( label )
	for i = 1, #statIds do
		local id = statIds[i]
		local expected = hudLayout.barWidth * model[id] / 100
		local row = statRow( i )
		local width = row.fill.width
		check( math.abs( width - expected ) < 0.01, label .. ": " .. id .. " bar " .. tostring( width ) .. " expected " .. expected )
		check( row.value.text == tostring( model[id] ), label .. ": " .. id .. " value " .. tostring( row.value.text ) .. " expected " .. model[id] )
	end
end

-- Opens the panel, reads every value and bar, and closes it with a click or Escape.
local function checkRelations( label, closeWithEscape )
	click( hudButtonX, hudButtonY )
	check( panelShown(), label .. ": Relationships panel opens" )

	for i = 1, #relationIds do
		local id = relationIds[i]
		local parent
		each( view, function( object )
			if object.text == panelLayout.title and object.parent.numChildren > 20 then
				parent = object.parent
			end
		end )
		local index
		for child = 1, parent.numChildren do
			if not index and parent[child].text == relationNames[id] then
				index = child
			end
		end
		local valueText, fill = parent[index + 2], parent[index + 3]
		local expectedWidth = panelLayout.barWidth * 0.5 * math.abs( model[id] ) / 100
		check( valueText.text == tostring( model[id] ), label .. ": " .. id .. " shows " .. valueText.text .. " expected " .. model[id] )
		check( math.abs( fill.width - expectedWidth ) < 0.01 and fill.anchorX == ( model[id] < 0 and 1 or 0 ), label .. ": " .. id .. " bar" )
	end

	if closeWithEscape then
		press( "escape" )
	else
		click( closeX, closeY )
	end
	check( not panelShown(), label .. ": Relationships panel closes" )
end

local function menuOpen()
	return shows( settings.hint.actions ) or shows( settings.hint.lastAction )
end

local function advanceUntilMenu( limit )
	for _ = 1, limit or 20 do
		if menuOpen() then
			return true
		end
		press( "space" )
	end
	return menuOpen()
end

local actionLayout = settings.actionMenu
local choiceLayout = settings.player.choices

local function actionY( index )
	return actionLayout.firstY + ( index - 1 ) * ( actionLayout.height + actionLayout.gap )
end

-- Picks an action and a choice with keys (Down from the first unused action) or with clicks.
local function playAction( actionIndex, choiceIndex, used, useKeys, label )
	if useKeys then
		local selected = 1
		while used[selected] do
			selected = selected + 1
		end

		while selected ~= actionIndex do
			press( "down" )
			repeat
				selected = selected % 5 + 1
			until not used[selected]
		end
		press( "enter" )
	else
		click( actionLayout.x, actionY( actionIndex ) )
	end

	check( not menuOpen(), label .. ": action " .. actionIndex .. " starts its passage" )
	used[actionIndex] = true

	-- Picking an action changes nothing and clears the last choice's changes beside the bars.
	checkStats( label .. " after the action" )
	for i = 1, #statIds do
		check( statRow( i ).change.text == "", label .. ": " .. statIds[i] .. " change cleared by the action pick" )
	end

	local buttons = choiceButtons()
	check( #buttons == 2, label .. ": two choices on screen" )
	for i = 1, #buttons do
		local preview = readPreview( buttons[i], label .. " choice " .. i )
		local passage = choicePassages[actionIndex][i]
		local expected = projectBible( passage, i == choiceIndex )
		if not samePreview( expected, effects[passage] ) then
			clampedPreviews = clampedPreviews + 1
		end
		local message = label .. ": choice " .. i .. " previews " .. describe( preview ) .. ", bible " .. describe( expected )
		check( buttons[i].target == passage and samePreview( preview, expected ), message )
	end

	local chosen = readPreview( buttons[choiceIndex], label .. " chosen" )
	local before = {}
	for i = 1, #statIds do
		before[statIds[i]] = model[statIds[i]]
	end

	if useKeys then
		for _ = 2, choiceIndex do
			press( "down" )
		end
		press( "enter" )
	else
		click( choiceLayout.x, choiceLayout.y + ( choiceIndex - 1 ) * ( choiceLayout.height + choiceLayout.gap ) )
	end

	-- The model follows what the chosen button showed, so every later bar and panel check compares the applied change with the preview.
	applyModel( chosen )
	steps( 40 )
	checkStats( label )

	for i = 1, #statIds do
		local id = statIds[i]
		local text = statRow( i ).change.text
		local message = label .. ": " .. id .. " change shows \"" .. tostring( text ) .. "\", preview " .. signed( chosen[id] or 0 )
		check( text == signed( chosen[id] or 0 ) and text == signed( model[id] - before[id] ), message )
	end
end

local function playWeek( plan, useKeys, label )
	resetModel()

	for dayNumber = 1, #plan do
		check( advanceUntilMenu(), label .. " day " .. dayNumber .. ": menu opens" )
		check( shows( string.format( "Day %d of 7", dayNumber ) ), label .. " day " .. dayNumber .. ": counter" )
		check( shows( settings.hint.actions ), label .. " day " .. dayNumber .. ": first-pick hint" )

		local used = {}
		local day = plan[dayNumber]

		-- No action changes anything by itself, so no action row shows a preview.
		local rows = actionRows()
		check( #rows == #settings.actions, label .. " day " .. dayNumber .. ": every action row found" )
		for i = 1, #rows do
			local _, hasRow = readPreview( rows[i], label .. " action " .. i )
			check( not hasRow and rows[i].label.y == 0, label .. " day " .. dayNumber .. ": action " .. i .. " shows no preview" )
		end
		playAction( day[1], day[2], used, useKeys, label .. " day " .. dayNumber .. " first" )
		check( advanceUntilMenu(), label .. " day " .. dayNumber .. ": menu opens for the second action" )
		check( shows( settings.hint.lastAction ), label .. " day " .. dayNumber .. ": second-pick hint" )

		-- A used action ignores clicks and Enter on it never happens since the highlight skips it.
		click( actionLayout.x, actionY( day[1] ) )
		check( menuOpen(), label .. " day " .. dayNumber .. ": used action ignores a click" )

		playAction( day[3], day[4], used, useKeys, label .. " day " .. dayNumber .. " second" )
		checkRelations( label .. " day " .. dayNumber, dayNumber % 2 == 0 )
	end
end

-- Opening
check( shows( "You're late. Again." ), "opening starts with the secretary" )
check( shows( "Day 1 of 7" ), "day counter starts at 1" )
resetModel()
checkStats( "start" )
checkRelations( "start" )
check( shows( "You're late. Again." ), "the story stays put after the panel" )

-- A click on the open panel never reaches the story.
click( hudButtonX, hudButtonY )
click( 480, 330 )
check( panelShown() and shows( "You're late. Again." ), "clicks on the panel stay on the panel" )
press( "space" )
check( shows( "You're late. Again." ), "Space does not advance the story under the panel" )
press( "escape" )
check( not panelShown(), "Escape closes the panel" )

-- Bars slide rather than jump.
check( advanceUntilMenu( 30 ), "opening reaches the first day" )
check( shows( "Where to now?" ) or shows( "The day is short." ) or shows( "So am I." ), "a Day line shows under the menu" )
click( 480, 470 )
check( menuOpen(), "a stage click leaves the menu open" )
click( actionLayout.x, actionY( 1 ) )
click( choiceLayout.x, choiceLayout.y )
steps( 3 )
local midWidth = statBar( 1 ).width
check( midWidth > hudLayout.barWidth * 0.2 and midWidth < hudLayout.barWidth * 0.35, "money bar is still sliding: " .. tostring( midWidth ) )

-- Restart through hide and show so the week starts from day 1.
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
steps( 2 )
check( shows( "You're late. Again." ) and shows( "Day 1 of 7" ), "re-entering starts fresh" )
resetModel()
checkStats( "re-entered" )
checkRelations( "re-entered" )

-- Week 1 pays: action, choice, action, choice per day.
clampsHit = {}
playWeek( {
	{ 1, 1, 5, 1 },
	{ 1, 1, 5, 1 },
	{ 1, 1, 2, 2 },
	{ 3, 1, 1, 2 },
	{ 3, 1, 5, 2 },
	{ 3, 1, 4, 2 },
	{ 3, 2, 4, 1 },
}, true, "paid" )
check( model.money >= settings.calendar.rent and model.health > settings.calendar.healthFloor, "paid path meets rent and health" )

local function advanceUntil( text, limit )
	for _ = 1, limit or 10 do
		if shows( text ) then
			return true
		end
		press( "space" )
	end
	return shows( text )
end

check( advanceUntil( "Seven days and the rent is paid." ), "paid ending plays" )
check( advanceUntil( settings.playAgain.label ), "Play again after the paid ending" )
check( shows( "I already did. In ink." ), "last ending line stays on screen" )

click( settings.playAgain.x, settings.playAgain.y )
check( shows( "You're late. Again." ) and shows( "Day 1 of 7" ), "Play again restarts the opening" )
resetModel()
checkStats( "after Play again" )
checkRelations( "after Play again" )
check( advanceUntilMenu( 30 ), "second week reaches day 1" )

-- Week 2 misses the rent, by clicks.
playWeek( {
	{ 4, 1, 2, 1 },
	{ 4, 1, 2, 1 },
	{ 4, 1, 2, 1 },
	{ 4, 1, 2, 1 },
	{ 4, 1, 2, 1 },
	{ 4, 1, 2, 1 },
	{ 4, 1, 2, 1 },
}, false, "missed" )
check( model.money < settings.calendar.rent, "missed path is short of rent" )
check( clampsHit["money bottom"] and clampsHit["jimmy bottom"] and clampsHit["briggs top"] and clampsHit["happiness top"], "clamps hit at both ends" )
check( clampedPreviews > 0, "some previews shrink at a limit: " .. clampedPreviews )

check( advanceUntil( "The rent isn't paid" ), "missed ending plays" )
check( advanceUntil( settings.playAgain.label ), "Play again after the missed ending" )
press( "enter" )
check( shows( "You're late. Again." ) and shows( "Day 1 of 7" ), "Enter on Play again restarts" )
resetModel()
checkStats( "after second Play again" )
checkRelations( "after second Play again", true )
check( advanceUntilMenu( 30 ), "third week reaches day 1" )

-- Week 3 has the rent but ends with Health exactly at the floor.
playWeek( {
	{ 1, 1, 5, 1 },
	{ 1, 1, 5, 1 },
	{ 1, 1, 5, 1 },
	{ 1, 1, 5, 1 },
	{ 5, 1, 4, 2 },
	{ 5, 1, 4, 2 },
	{ 5, 1, 4, 2 },
}, true, "worn out" )
check( model.money >= settings.calendar.rent and model.health == settings.calendar.healthFloor, "worn-out path has the rent and Health at the floor" )
check( advanceUntil( "You look like you haven't slept all week." ), "worn-out ending plays" )
check( not shows( "The rent isn't paid" ) and not shows( "The landlord even said thank you." ), "no other ending line" )
check( advanceUntil( settings.playAgain.label ), "Play again after the worn-out ending" )
click( settings.playAgain.x, settings.playAgain.y )
check( shows( "You're late. Again." ), "Play again restarts after the worn-out ending" )

stub.sceneEvent( scene, "hide", "will" )
press( "space" )
press( "enter" )
stub.sceneEvent( scene, "hide", "did" )
check( stub.activeTransitionCount() == 0, "no transitions after hide, keys pressed during the fade" )
stub.sceneEvent( scene, "destroy" )
check( rawget( _G, "WEAVERxRosoNoirLifeSim" ) == nil, "Weaver cache cleared on destroy" )

-- The preview refuses passages whose changes it could not promise.
local effectPreview = require( "samples.visual-novel-life-sim.classes.effectPreview" )
local json = require( "json" )
local fixtureFolder = ".scratch/tmp/visual-novel-life-sim"
lfs.mkdir( ".scratch" )
lfs.mkdir( ".scratch/tmp" )
lfs.mkdir( fixtureFolder )

local function readFixture( body )
	local path = fixtureFolder .. "/preview-fixture.json"
	local file = io.open( path, "w" )
	file:write( json.encode( { { title = "Fixture", tags = "", body = body } } ) )
	file:close()
	return pcall( effectPreview.readStory, path, settings.stats, settings.relationships )
end

local isRead, result = readFixture( "<<stat, money, 5>>\n<<stat, money, -2>>\n<<relation, mae, 3>>\n<<endAction>>" )
check( isRead and #result.Fixture == 3 and result.Fixture[2].amount == -2 and result.Fixture[3].kind == "relation", "plain rows read in order" )

local guards = {
	{ "<<if($x)>>\n<<stat, money, 5>>\n<<end>>", "inside <<if>>" },
	{ "<<if $x > 1>>\n<<stat, money, 5>>\n<<end>>", "inside <<if>>" },
	{ "<<endAction>>\n<<stat, money, 5>>", "after leaving" },
	{ "<<jump, Day>>\n<<relation, mae, 5>>", "after leaving" },
	{ "<<stat, cash, 5>>", "unreadable row" },
}
for i = 1, #guards do
	local isFine, message = readFixture( guards[i][1] )
	check( not isFine and string.find( tostring( message ), guards[i][2], 1, true ) ~= nil, "preview refuses fixture " .. i .. ": " .. tostring( message ) )
end

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
