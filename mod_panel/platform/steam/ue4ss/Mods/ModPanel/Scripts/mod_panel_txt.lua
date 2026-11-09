-- A JavaScript mod's settings file, Key=Value lines, read and written as Mods Menu 0.9.3 reads and writes it, so a mod
-- shows and saves the same in both menus. A key's line: spaces, the key in any case, spaces, =, spaces, the value up
-- to a ; or # (a comment), its spaces at the end not part of it. The first line of a key wins when reading; writing
-- changes every line of the key, or adds one at the end; the rest of the text stays as it is.

local Values = require("mod_panel_values")

local M = {}

-- The game's text reader refuses a file of 10 characters or fewer, so a short file starts with a comment line.
local SHORT = 10

local function strip_bom(text)
	if text:sub(1, 3) == "\239\187\191" then return text:sub(4) end
	return text
end

-- The line's parts when it sets key: what goes before the value, the value, what goes after; nil otherwise.
local function key_line(line, key)
	local lead, rest = line:match("^([ \t]*)(.*)$")
	if rest:sub(1, #key):lower() ~= key:lower() then return nil end
	local mid, after = rest:sub(#key + 1):match("^([ \t]*=[ \t]*)(.*)$")
	if mid == nil then return nil end
	local cut = after:find("[;#\r\n]") or (#after + 1)
	local value, comment = after:sub(1, cut - 1), after:sub(cut)
	local body, spaces = value:match("^(.-)([ \t]*)$")
	return lead .. rest:sub(1, #key) .. mid, body, spaces .. comment
end

-- The value of key in text: its first line's, or nil when no line sets it.
function M.read_key(text, key)
	for line in (strip_bom(text) .. "\n"):gmatch("([^\n]*)\n") do
		local _, value = key_line(line:gsub("\r$", ""), key)
		if value ~= nil then return (value:match("^%s*(.-)%s*$")) end
	end
	return nil
end

-- The text a value is written as, as Mods Menu writes it in a text file: a toggle On or Off, a number as shown.
function M.literal(row, v)
	if row.type == "toggle" then return v and "On" or "Off" end
	if row.type == "number" then return Values.format_number(v, row) end
	return Values.js_string(v)
end

-- text with each { key, value } of list written in (value already a literal); text nil makes a new file under header.
function M.set(text, list, header)
	local parts = {}  -- line, ending, line, ending, ..., last line
	local source = text and strip_bom(text) or (header .. "\r\n")
	local at = 1
	while true do
		local s, e = source:find("\r?\n", at)
		if s == nil then break end
		parts[#parts + 1] = source:sub(at, s - 1)
		parts[#parts + 1] = source:sub(s, e)
		at = e + 1
	end
	parts[#parts + 1] = source:sub(at)
	local eol = parts[2] or "\r\n"
	for _, c in ipairs(list) do
		local key, value, hit = c[1], c[2], false
		for i = 1, #parts, 2 do
			local before, _, after = key_line(parts[i], key)
			if before ~= nil then
				parts[i] = before .. value .. after
				hit = true
			end
		end
		if not hit then
			if parts[#parts] == "" then
				table.insert(parts, #parts, key .. "=" .. value)
				table.insert(parts, #parts, eol)
			else
				parts[#parts + 1] = eol
				parts[#parts + 1] = key .. "=" .. value
			end
		end
	end
	local out = table.concat(parts)
	if #out > SHORT then return out end
	return header .. eol .. out
end

return M
