-- Reads a JSON text whose values hold other values (objects in arrays, as in DynamicFOV.modsmenu.json). The settings
-- file goes through dynamic_fov_json.lua instead, a copy of Dodge Jump's kept identical to it, which reads flat objects
-- only. An object becomes a table by key, an array a sequence; null is left out. A text nested deeper than MAX_DEPTH,
-- or not valid JSON, gives nil and the reason.

local M = {}

local MAX_DEPTH = 16
local BOM = "\239\187\191"
local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local read_value

local function fail(at, what)
	error({ at = at, what = what }, 0)
end

local function skip(text, i)
	return text:find("[^ \t\r\n]", i) or #text + 1
end

local function hex4(text, i)
	local h = text:match("^%x%x%x%x", i)
	if h == nil then fail(i, "a \\u escape needs four hex digits") end
	return tonumber(h, 16)
end

-- A \u escape at i (the backslash), a surrogate pair as one character; returns the character and where reading goes on.
local function unicode(text, i)
	local code, after = hex4(text, i + 2), i + 6
	if code >= 0xD800 and code <= 0xDBFF and text:sub(after, after + 1) == "\\u" then
		local low = hex4(text, after + 2)
		if low >= 0xDC00 and low <= 0xDFFF then
			code, after = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00), after + 6
		end
	end
	return utf8.char(code), after
end

local function read_string(text, i)
	local parts, j = {}, i + 1
	while true do
		local k = text:find('["\\\0-\31]', j)
		if k == nil then fail(i, "a string is not closed") end
		parts[#parts + 1] = text:sub(j, k - 1)
		local c = text:sub(k, k)
		if c == '"' then return table.concat(parts), k + 1 end
		if c ~= "\\" then fail(k, "a control character in a string") end
		local e = text:sub(k + 1, k + 1)
		if e == "u" then
			parts[#parts + 1], j = unicode(text, k)
		elseif ESCAPES[e] ~= nil then
			parts[#parts + 1], j = ESCAPES[e], k + 2
		else
			fail(k, "an unknown escape in a string")
		end
	end
end

local function read_number(text, i)
	local whole = text:match("^-?%d+", i)
	if whole == nil then fail(i, "a value is expected") end
	local j = i + #whole
	local fraction = text:match("^%.%d+", j)
	if fraction then j = j + #fraction end
	local exponent = text:match("^[eE][-+]?%d+", j)
	if exponent then j = j + #exponent end
	return tonumber(text:sub(i, j - 1)), j
end

local function read_array(text, i, depth)
	local list, j = {}, skip(text, i + 1)
	if text:sub(j, j) == "]" then return list, j + 1 end
	while true do
		local v
		v, j = read_value(text, j, depth)
		list[#list + 1] = v
		j = skip(text, j)
		local c = text:sub(j, j)
		if c == "]" then return list, j + 1 end
		if c ~= "," then fail(j, "a , or ] is expected in an array") end
		j = skip(text, j + 1)
	end
end

local function read_object(text, i, depth)
	local object, j = {}, skip(text, i + 1)
	if text:sub(j, j) == "}" then return object, j + 1 end
	while true do
		if text:sub(j, j) ~= '"' then fail(j, "a key is expected") end
		local key, v
		key, j = read_string(text, j)
		j = skip(text, j)
		if text:sub(j, j) ~= ":" then fail(j, "a : is expected after a key") end
		v, j = read_value(text, skip(text, j + 1), depth)
		object[key] = v
		j = skip(text, j)
		local c = text:sub(j, j)
		if c == "}" then return object, j + 1 end
		if c ~= "," then fail(j, "a , or } is expected in an object") end
		j = skip(text, j + 1)
	end
end

function read_value(text, i, depth)
	local c = text:sub(i, i)
	if c == "{" or c == "[" then
		if depth >= MAX_DEPTH then fail(i, "values nested too deep") end
		return (c == "{" and read_object or read_array)(text, i, depth + 1)
	end
	if c == '"' then return read_string(text, i) end
	if text:sub(i, i + 3) == "true" then return true, i + 4 end
	if text:sub(i, i + 4) == "false" then return false, i + 5 end
	if text:sub(i, i + 3) == "null" then return nil, i + 4 end
	return read_number(text, i)
end

local function decode(text)
	local start = text:sub(1, #BOM) == BOM and #BOM + 1 or 1
	local v, j = read_value(text, skip(text, start), 0)
	j = skip(text, j)
	if j <= #text then fail(j, "more after the value") end
	return v
end

-- The value in text, or nil and the reason.
function M.decode(text)
	if type(text) ~= "string" then return nil, "no text" end
	local ok, v = pcall(decode, text)
	if ok then return v end
	if type(v) == "table" then return nil, string.format("%s at byte %d", v.what, v.at) end
	return nil, tostring(v)
end

return M
