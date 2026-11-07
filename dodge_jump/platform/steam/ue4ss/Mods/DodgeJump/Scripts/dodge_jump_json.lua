-- Reads and writes one flat JSON object of strings, numbers, true, false and null: the format of the config files
-- Mods Menu (Nexus 149) edits. Nested objects and arrays are refused, the menu never writes them. UE4SS ships no
-- JSON library, hence this one.

local M = {}

local MAX_KEYS = 64
local BOM = "\239\187\191"
local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
local QUOTED = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

-- Returns the object as a table, or nil and the reason. A null value leaves its key out.
function M.decode(text)
	if type(text) ~= "string" then return nil, "no text" end
	local pos = text:sub(1, 3) == BOM and 4 or 1

	local function skip()
		pos = text:find("[^ \t\r\n]", pos) or #text + 1
	end

	local function read_string()
		local parts, i = {}, pos + 1
		while true do
			local j = text:find('[%c"\\]', i)
			if j == nil then return nil end
			parts[#parts + 1] = text:sub(i, j - 1)
			local c = text:sub(j, j)
			if c == '"' then
				pos = j + 1
				return table.concat(parts)
			elseif c ~= "\\" then
				return nil
			end
			local e = text:sub(j + 1, j + 1)
			if e == "u" then
				local hex = text:sub(j + 2, j + 5)
				if not hex:match("^%x%x%x%x$") then return nil end
				parts[#parts + 1] = utf8.char(tonumber(hex, 16))
				i = j + 6
			elseif ESCAPES[e] ~= nil then
				parts[#parts + 1] = ESCAPES[e]
				i = j + 2
			else
				return nil
			end
		end
	end

	-- Returns ok, value (value nil for null).
	local function read_value()
		local c = text:sub(pos, pos)
		if c == '"' then
			local s = read_string()
			return s ~= nil, s
		end
		if text:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true, true
		elseif text:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return true, false
		elseif text:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return true, nil
		end
		local digits = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		local n = digits and tonumber(digits)
		if n == nil then return false end
		pos = pos + #digits
		return true, n
	end

	skip()
	if text:sub(pos, pos) ~= "{" then return nil, "not a JSON object" end
	pos = pos + 1
	local out, count = {}, 0
	skip()
	if text:sub(pos, pos) == "}" then
		pos = pos + 1
	else
		while true do
			skip()
			if text:sub(pos, pos) ~= '"' then return nil, "a key is not a string" end
			local key = read_string()
			if key == nil then return nil, "a key is not a valid string" end
			skip()
			if text:sub(pos, pos) ~= ":" then return nil, "missing ':' after \"" .. key .. "\"" end
			pos = pos + 1
			skip()
			local c = text:sub(pos, pos)
			if c == "{" or c == "[" then return nil, "\"" .. key .. "\" holds a list or an object" end
			local ok, value = read_value()
			if not ok then return nil, "\"" .. key .. "\" has no valid value" end
			count = count + 1
			if count > MAX_KEYS then return nil, "more than " .. MAX_KEYS .. " keys" end
			out[key] = value
			skip()
			c = text:sub(pos, pos)
			pos = pos + 1
			if c == "}" then break end
			if c ~= "," then return nil, "missing ',' or '}' after \"" .. key .. "\"" end
		end
	end
	skip()
	if pos <= #text then return nil, "text after the object" end
	return out
end

local function quote(s)
	return '"' .. s:gsub('[%c"\\]', function(c) return QUOTED[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function literal(v)
	if type(v) == "string" then return quote(v) end
	if math.type(v) == "integer" then return string.format("%d", v) end
	if type(v) == "number" then return string.format("%.17g", v) end
	return tostring(v)
end

-- entries: { { key, value }, ... } in the order to write; values are strings, numbers or booleans.
function M.encode(entries)
	local lines = {}
	for i, e in ipairs(entries) do
		lines[i] = "  " .. quote(e[1]) .. ": " .. literal(e[2])
	end
	return "{\n" .. table.concat(lines, ",\n") .. "\n}\n"
end

return M
