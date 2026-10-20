-- A small JSON decoder standing in for Solar2D's json library under stock Lua 5.1.
-- Copyright (c) 2026 Eetu Rantanen. MIT License.
-- null decodes to nil, as Solar2D's json.decode does by default.

local json = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local escapes = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	["b"] = "\b",
	["f"] = "\f",
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "\t",
}

local literals = {
	["true"] = true,
	["false"] = false,
}

local parseValue

--------------------------------------------------------------------------------------
-- Private functions

local function decodeError( text, position, message )
	local line = 1

	for _ in string.gmatch( string.sub( text, 1, position ), "\n" ) do
		line = line + 1
	end

	error( "json.decode: " .. message .. " at line " .. line .. " (byte " .. position .. ")", 0 )
end

local function skipWhitespace( text, position )
	local nextPosition = string.find( text, "[^ \t\r\n]", position )

	return nextPosition or #text + 1
end

local function codepointToUtf8( code )
	if code < 0x80 then
		return string.char( code )

	elseif code < 0x800 then
		return string.char( 0xC0 + math.floor( code / 0x40 ), 0x80 + code % 0x40 )

	elseif code < 0x10000 then
		return string.char( 0xE0 + math.floor( code / 0x1000 ), 0x80 + math.floor( code / 0x40 ) % 0x40, 0x80 + code % 0x40 )
	end

	return string.char( 0xF0 + math.floor( code / 0x40000 ), 0x80 + math.floor( code / 0x1000 ) % 0x40,
		0x80 + math.floor( code / 0x40 ) % 0x40, 0x80 + code % 0x40 )
end

local function parseHex4( text, position )
	local hex = string.match( text, "^%x%x%x%x", position )

	if not hex then
		decodeError( text, position, "invalid \\u escape" )
	end

	return tonumber( hex, 16 )
end

local function parseString( text, position )
	local parts = {}
	local index = position + 1

	while true do
		local stop = string.find( text, '["\\]', index )

		if not stop then
			decodeError( text, position, "unterminated string" )
		end

		parts[#parts + 1] = string.sub( text, index, stop - 1 )

		if string.sub( text, stop, stop ) == '"' then
			return table.concat( parts ), stop + 1
		end

		local escape = string.sub( text, stop + 1, stop + 1 )

		if escape == "u" then
			local code = parseHex4( text, stop + 2 )
			index = stop + 6

			-- A high surrogate followed by a low one encodes a single codepoint above U+FFFF.
			if code >= 0xD800 and code <= 0xDBFF and string.sub( text, index, index + 1 ) == "\\u" then
				local low = parseHex4( text, index + 2 )

				if low >= 0xDC00 and low <= 0xDFFF then
					code = 0x10000 + ( code - 0xD800 ) * 0x400 + ( low - 0xDC00 )
					index = index + 6
				end
			end

			parts[#parts + 1] = codepointToUtf8( code )

		elseif escapes[escape] then
			parts[#parts + 1] = escapes[escape]
			index = stop + 2

		else
			decodeError( text, stop, "invalid escape" )
		end
	end
end

local function parseNumber( text, position )
	local token = string.match( text, "^-?%d+%.?%d*[eE]?[-+]?%d*", position )
	local value = token and tonumber( token )

	if not value then
		decodeError( text, position, "invalid number" )
	end

	return value, position + #token
end

local function parseArray( text, position )
	local array = {}
	local count = 0
	position = skipWhitespace( text, position + 1 )

	if string.sub( text, position, position ) == "]" then
		return array, position + 1
	end

	while true do
		local value
		value, position = parseValue( text, position )

		-- Counted explicitly so a null element keeps the later elements at their indices.
		count = count + 1
		array[count] = value

		position = skipWhitespace( text, position )
		local character = string.sub( text, position, position )

		if character == "]" then
			return array, position + 1

		elseif character ~= "," then
			decodeError( text, position, "expected ',' or ']'" )
		end

		position = skipWhitespace( text, position + 1 )
	end
end

local function parseObject( text, position )
	local object = {}
	position = skipWhitespace( text, position + 1 )

	if string.sub( text, position, position ) == "}" then
		return object, position + 1
	end

	while true do
		if string.sub( text, position, position ) ~= '"' then
			decodeError( text, position, "expected a string key" )
		end

		local key
		key, position = parseString( text, position )
		position = skipWhitespace( text, position )

		if string.sub( text, position, position ) ~= ":" then
			decodeError( text, position, "expected ':'" )
		end

		local value
		value, position = parseValue( text, skipWhitespace( text, position + 1 ) )
		object[key] = value

		position = skipWhitespace( text, position )
		local character = string.sub( text, position, position )

		if character == "}" then
			return object, position + 1

		elseif character ~= "," then
			decodeError( text, position, "expected ',' or '}'" )
		end

		position = skipWhitespace( text, position + 1 )
	end
end

function parseValue( text, position )
	position = skipWhitespace( text, position )
	local character = string.sub( text, position, position )

	if character == "{" then
		return parseObject( text, position )

	elseif character == "[" then
		return parseArray( text, position )

	elseif character == '"' then
		return parseString( text, position )

	elseif string.find( character, "[-%d]" ) then
		return parseNumber( text, position )
	end

	local word = string.match( text, "^%a+", position )

	if word == "null" then
		return nil, position + 4

	elseif word and literals[word] ~= nil then
		return literals[word], position + #word
	end

	decodeError( text, position, "unexpected character '" .. character .. "'" )
end

--------------------------------------------------------------------------------------
-- Public functions

function json.decode( text )
	local value, position = parseValue( text, 1 )
	position = skipWhitespace( text, position )

	if position <= #text then
		decodeError( text, position, "trailing characters" )
	end

	return value
end

--------------------------------------------------------------------------------------

return json
