-- Which string set is showing: Finnish by default, English when an HTML5 build's hosting page sits under /en/.

local language = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local strings = require( "data.strings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local DEFAULT_CODE = "fi"
local ENGLISH_PATH = "/en/"

local currentCode = DEFAULT_CODE

--------------------------------------------------------------------------------------
-- Private functions

-- In the Simulator the platform is the skin's operating system, so the plugin only loads in a real HTML5 build.
local function detectFromPage()
	if system.getInfo( "platform" ) ~= "html5" then
		return nil
	end

	local isLoaded, plugin = pcall( require, "plugin.pageUrl" )

	if not isLoaded or type( plugin ) ~= "table" or type( plugin.getPageUrl ) ~= "function" then
		print( "WARNING: ball-prototype-demo: plugin_pageUrl.js did not load, defaulting to " .. DEFAULT_CODE .. "." )
		return nil
	end

	local url = plugin.getPageUrl()

	if type( url ) ~= "string" then
		print( "WARNING: ball-prototype-demo: plugin_pageUrl.js returned no page URL, defaulting to " .. DEFAULT_CODE .. "." )
		return nil
	end

	if string.find( string.lower( url ), ENGLISH_PATH, 1, true ) then
		return "en"
	end

	return nil
end

--------------------------------------------------------------------------------------
-- Public functions

function language.init()
	currentCode = detectFromPage() or DEFAULT_CODE

	return currentCode
end

function language.get()
	return currentCode
end

function language.toggle()
	currentCode = currentCode == "fi" and "en" or "fi"

	return currentCode
end

function language.strings()
	return strings[currentCode]
end

--------------------------------------------------------------------------------------

return language
