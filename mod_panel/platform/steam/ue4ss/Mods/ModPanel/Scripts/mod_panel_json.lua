-- JSON as Mods Menu reads it, for the mods' files; the writing is mod_panel_json_edit.lua's (one module reads, the
-- other writes). Taken from Dynamic FOV 1.0.4's reader (dynamic_fov_json_tree.lua), with what Mods Menu's checks need
-- besides: an array is told from an object, null is kept (M.NULL) where Mods Menu sees it, an object keeps the order of
-- its keys, every number is a float as in JavaScript, and a number with a leading zero is refused as JSON.parse refuses
-- it. Also the places of an object's members, for a change in place, and a number as JavaScript writes it, which the
-- panel shows too.

local M = {}

M.NULL = setmetatable({}, { __tostring = function() return "null" end })
local ARRAY = {}
-- 32 levels (audit of 0.4.3: at 16, a field Mod Panel does not use, nested deeper, refused the whole descriptor while
-- Mods Menu read it). Two Lua calls a level, under Lua 5.4's 200 nested calls with room for the hook's own.
local MAX_DEPTH = 32
local BOM = "\239\187\191"
local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
-- The keys of each object read, in the order of the text; a key given twice keeps its first place and its last value,
-- as in JavaScript.
local ORDER = setmetatable({}, { __mode = "k" })

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
	if whole:match("^-?0%d") then fail(i, "a number starts with 0") end
	local j = i + #whole
	local fraction = text:match("^%.%d+", j)
	if fraction then j = j + #fraction end
	local exponent = text:match("^[eE][-+]?%d+", j)
	if exponent then j = j + #exponent end
	return tonumber(text:sub(i, j - 1)) + 0.0, j
end

local function read_array(text, i, depth)
	local list, j = setmetatable({}, ARRAY), skip(text, i + 1)
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
	local object, order, j = {}, {}, skip(text, i + 1)
	ORDER[object] = order
	if text:sub(j, j) == "}" then return object, j + 1 end
	while true do
		if text:sub(j, j) ~= '"' then fail(j, "a key is expected") end
		local key, v
		key, j = read_string(text, j)
		j = skip(text, j)
		if text:sub(j, j) ~= ":" then fail(j, "a : is expected after a key") end
		v, j = read_value(text, skip(text, j + 1), depth)
		if object[key] == nil then order[#order + 1] = key end
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
	if text:sub(i, i + 3) == "null" then return M.NULL, i + 4 end
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

function M.is_array(v)
	return type(v) == "table" and getmetatable(v) == ARRAY
end

-- An object read from JSON (not an array, not null).
function M.is_object(v)
	return type(v) == "table" and getmetatable(v) == nil
end

-- The keys of an object read by M.decode, in the order of its text.
function M.keys(object)
	return ORDER[object] or {}
end

local function members(text)
	local i = skip(text, text:sub(1, #BOM) == BOM and #BOM + 1 or 1)
	if text:sub(i, i) ~= "{" then fail(i, "the text is not one object") end
	local list, j = {}, skip(text, i + 1)
	local close = nil
	if text:sub(j, j) == "}" then close = j end
	while close == nil do
		if text:sub(j, j) ~= '"' then fail(j, "a key is expected") end
		local m = { key_from = j }
		m.key, j = read_string(text, j)
		m.key_to, j = j - 1, skip(text, j)
		if text:sub(j, j) ~= ":" then fail(j, "a : is expected after a key") end
		m.from = skip(text, j + 1)
		local _, after = read_value(text, m.from, 1)
		m.to = after - 1
		list[#list + 1] = m
		j = skip(text, after)
		local c = text:sub(j, j)
		if c == "}" then
			close = j
		elseif c ~= "," then
			fail(j, "a , or } is expected in an object")
		else
			j = skip(text, j + 1)
		end
	end
	if skip(text, close + 1) <= #text then fail(close + 1, "more after the object") end
	return list, close
end

-- The members of the one object text holds, in the order of the text, for a change in place (D35): each { key,
-- key_from, key_to, from, to }, where text:sub(key_from, key_to) is the key's quoted text and text:sub(from, to) its
-- value's, a key given twice listed at each of its places; then the place of the object's closing brace. nil and why
-- when text is not one JSON object.
function M.members(text)
	if type(text) ~= "string" then return nil, "no text" end
	local ok, list, close = pcall(members, text)
	if ok then return list, close end
	if type(list) == "table" then return nil, string.format("%s at byte %d", list.what, list.at) end
	return nil, tostring(list)
end

-- A number as JavaScript writes it (String(n), JSON.stringify): the fewest digits that read back as the same number,
-- with an exponent from 1e21 up and below 1e-6. Where two of those are as short, the nearest to the number is taken,
-- which is the rounding of string.format.
function M.number_text(n)
	if n ~= n then return "NaN" end
	if n == math.huge then return "Infinity" end
	if n == -math.huge then return "-Infinity" end
	if n == 0 then return "0" end
	local sign, a = n < 0 and "-" or "", math.abs(n)
	local digits, exponent
	for p = 0, 16 do
		local s = string.format("%." .. p .. "e", a)
		if tonumber(s) == a or p == 16 then
			local mantissa, e = s:match("^([%d%.]+)e([-+]%d+)$")
			digits, exponent = mantissa:gsub("%.", ""):gsub("0+$", ""), tonumber(e)
			break
		end
	end
	local k, point = #digits, exponent + 1
	if k <= point and point <= 21 then return sign .. digits .. string.rep("0", point - k) end
	if 0 < point and point <= 21 then return sign .. digits:sub(1, point) .. "." .. digits:sub(point + 1) end
	if -6 < point and point <= 0 then return sign .. "0." .. string.rep("0", -point) .. digits end
	local e = point - 1
	local tail = string.format("e%s%d", e < 0 and "-" or "+", math.abs(e))
	if k == 1 then return sign .. digits .. tail end
	return sign .. digits:sub(1, 1) .. "." .. digits:sub(2) .. tail
end

return M
