-- JSON as Mods Menu writes a mod's settings (ASCII only), and a change in place (D35): only the values the player
-- changed are written over, every other character of the file stays as it was (keys Mod Panel does not know, their
-- order, spacing and line endings), so a mod's own reader finds its file as it left it. A key the file lacks is added
-- before the closing brace, in the file's own layout. Reading is mod_panel_json.lua's.

local Json = require("mod_panel_json")

local M = {}

local NAMED = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r",
	["\t"] = "\\t" }
local INDENT = "  "               -- the first key of an empty object, as JSON.stringify(object, null, 2) indents

-- A UTF-16 unit as \uXXXX, lowercase as Mods Menu writes it.
local function unit(code)
	return string.format("\\u%04x", code)
end

local function escaped(c)
	return NAMED[c] or unit(c:byte())
end

local function string_text(s)
	local out = s:gsub('[%c"\\]', escaped)
	-- Mods Menu writes a config in ASCII only: every character from U+007F on as \uXXXX, a
	-- character beyond U+FFFF as its two UTF-16 units. A byte that is not UTF-8 is written as its own code. Lax: a lone
	-- surrogate read from a \u escape is written back as one.
	return (out:gsub("[\127-\255][\128-\191]*", function(c)
		local ok, code = pcall(utf8.codepoint, c, 1, 1, true)
		if not ok or #c ~= #utf8.char(code) then
			return (c:gsub(".", function(b) return unit(b:byte()) end))
		end
		if code < 0x10000 then return unit(code) end
		code = code - 0x10000
		return unit(0xD800 + (code >> 10)) .. unit(0xDC00 + (code & 0x3FF))
	end))
end

-- A value as JSON.stringify writes it in Mods Menu's ASCII form: a boolean, a number (null when not finite), a text, a
-- list of these or of such lists on one line (the mods All mods turned off, the sections folded, mod_panel_state.lua),
-- or null.
function M.literal(v)
	local t = type(v)
	if t == "boolean" then return tostring(v) end
	if t == "number" then return (v ~= v or v == math.huge or v == -math.huge) and "null" or Json.number_text(v) end
	if t == "string" then return '"' .. string_text(v) .. '"' end
	if t == "table" then
		local parts = {}
		for i, x in ipairs(v) do parts[i] = M.literal(x) end
		return "[" .. table.concat(parts, ", ") .. "]"
	end
	return "null"
end

-- A flat object's text as Mods Menu writes a config (JSON.stringify(object, null, 2), then CRLF): entries is a list of
-- { key, value } in order.
function M.flat_object(entries)
	if #entries == 0 then return "{}\r\n" end
	local lines = {}
	for i, e in ipairs(entries) do
		lines[i] = INDENT .. M.literal(e[1]) .. ": " .. M.literal(e[2])
	end
	return "{\n" .. table.concat(lines, ",\n") .. "\n}\r\n"
end

-- How the file lays out a member, from its first one: what goes between two members (", " on one line, or a comma, the
-- line ending and the indent), and between a key and its value.
local function layout(text, first)
	local newline = text:find("\r\n", 1, true) and "\r\n" or "\n"
	if first == nil then return "," .. newline .. INDENT, ": ", newline end
	local line_start = 1
	for i = first.key_from - 1, 1, -1 do
		local c = text:sub(i, i)
		if c == "\n" then
			line_start = i + 1
			break
		end
	end
	local indent = text:sub(line_start, first.key_from - 1)
	local between = indent:match("^[ \t]*$") and line_start > 1 and ("," .. newline .. indent) or ", "
	return between, text:sub(first.key_to + 1, first.from - 1), newline
end

-- text with changes made: a list of { key, value }, the values as the file holds them (Values.to_file), in the order
-- of the rows. Each changed key's value is written over at each of its places; a key the file lacks is added before
-- the closing brace, the missing ones in the order given. Returns the new text, or nil and why when text is not one
-- JSON object.
function M.set(text, changes)
	local list, close = Json.members(text)
	if list == nil then return nil, close end
	local by_key, missing = {}, {}
	for _, c in ipairs(changes) do by_key[c[1]] = c end
	local edits, found = {}, {}
	for _, m in ipairs(list) do
		local c = by_key[m.key]
		if c ~= nil then
			edits[#edits + 1] = { from = m.from, to = m.to, text = M.literal(c[2]) }
			found[m.key] = true
		end
	end
	for _, c in ipairs(changes) do
		if not found[c[1]] then missing[#missing + 1] = c end
	end
	if #missing > 0 then
		local between, colon, newline = layout(text, list[1])
		local parts = {}
		for i, c in ipairs(missing) do
			parts[#parts + 1] = (i > 1 or #list > 0) and between or ""
			parts[#parts + 1] = M.literal(c[1]) .. colon .. M.literal(c[2])
		end
		if #list > 0 then
			local last = list[#list]
			edits[#edits + 1] = { from = last.to + 1, to = last.to, text = table.concat(parts) }
		else
			-- An empty object: its first keys on lines of their own, whatever was between its braces.
			local open = close - 1
			while text:sub(open, open) ~= "{" do open = open - 1 end
			edits[#edits + 1] = { from = open + 1, to = close - 1,
				text = newline .. INDENT .. table.concat(parts) .. newline }
		end
	end
	-- From the end of the text back, so that each place found above still holds.
	table.sort(edits, function(a, b) return a.from > b.from end)
	for _, e in ipairs(edits) do
		text = text:sub(1, e.from - 1) .. e.text .. text:sub(e.to + 1)
	end
	return text
end

return M
