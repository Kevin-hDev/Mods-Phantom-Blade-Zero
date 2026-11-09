-- The rules of Mods Menu 0.8.3 for a row's value, copied in Lua so that a mod shows, steps and saves the same in both
-- menus: how a file's value is read (from_raw), shown (format_number), stepped (step), placed on a bar (fraction,
-- at_fraction) and written (to_file). A row is a checked row of mod_panel_descriptor.lua. JavaScript's String(),
-- Number() and toFixed() are copied too, since the rules lean on them. Lower case is ASCII only, where JavaScript's
-- toLowerCase knows every alphabet: an option told apart only by the case of a letter beyond ASCII is not found.

local Json = require("mod_panel_json")
local Text = require("mod_panel_text")

local M = {}

M.NUMBER = "^[-+]?%d*%.?%d+$"
local NUMBER = M.NUMBER
-- Mods Menu's switch words; a number 1 or 0 counts as its text.
local BOOL = { on = true, ["true"] = true, yes = true, ["1"] = true, off = false, ["false"] = false, no = false,
	["0"] = false }

local function finite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function round(x)
	return math.floor(x + 0.5)
end

-- JavaScript's String(v) for a value read from JSON.
function M.js_string(v)
	local t = type(v)
	if t == "string" then return v end
	if t == "number" then return Json.number_text(v) end
	if t == "boolean" then return tostring(v) end
	if v == nil then return "undefined" end
	if v == Json.NULL then return "null" end
	if Json.is_array(v) then
		local parts = {}
		for i, e in ipairs(v) do parts[i] = e == Json.NULL and "" or M.js_string(e) end
		return table.concat(parts, ",")
	end
	return "[object Object]"
end

local BASES = { x = { 16, "^%x+$" }, b = { 2, "^[01]+$" }, o = { 8, "^[0-7]+$" } }

-- JavaScript's Number(s) for a text: decimal, 0x, 0b and 0o forms, Infinity; NaN for anything else.
function M.js_number(s)
	local t = Text.trim(s)
	if t == "" then return 0.0 end
	local sign, body = t:match("^([+-]?)(.*)$")
	if body == "Infinity" then return sign == "-" and -math.huge or math.huge end
	local base = sign == "" and body:match("^0([xXbBoO])")
	if base then
		local b = BASES[base:lower()]
		local digits = body:sub(3)
		if not digits:match(b[2]) then return 0 / 0 end
		local n = 0.0
		for c in digits:gmatch(".") do n = n * b[1] + tonumber(c, 16) end
		return n
	end
	if body:match("^%d+%.?%d*$") or body:match("^%.%d+$") or body:match("^%d+%.?%d*[eE][-+]?%d+$")
		or body:match("^%.%d+[eE][-+]?%d+$") then
		return tonumber(sign .. body) + 0.0
	end
	return 0 / 0
end

-- The digits of d, one added to its last.
local function plus_one(d)
	local i = #d
	while i > 0 and d:sub(i, i) == "9" do i = i - 1 end
	if i == 0 then return "1" .. string.rep("0", #d) end
	return d:sub(1, i - 1) .. tostring(tonumber(d:sub(i, i)) + 1) .. string.rep("0", #d - i)
end

-- JavaScript's n.toFixed(d). Where n lies exactly half way between two d-decimal numbers, JavaScript takes the larger
-- in size (0.0625 at 3 decimals: 0.063), while string.format takes the even one (0.062). Such a tie has d + 1 decimals
-- exactly, the last a 5, which %.60f writes in full.
function M.to_fixed(n, d)
	if n ~= n then return "NaN" end
	if math.abs(n) >= 1e21 then return Json.number_text(n) end
	local a = math.abs(n)
	local s = string.format("%." .. d .. "f", a)
	local whole, decimals = string.format("%.60f", a):match("^(%d+)%.(%d+)$")
	if decimals:sub(d + 1, d + 1) == "5" and not decimals:sub(d + 2):find("[1-9]") then
		local up = plus_one(whole .. decimals:sub(1, d))
		s = d == 0 and up or up:sub(1, #up - d) .. "." .. up:sub(#up - d + 1)
	end
	return (n < 0 and "-" or "") .. s
end

-- The decimals of n, as Mods Menu counts them: as JavaScript writes it, 6 for a small number with an exponent.
function M.decimals(n)
	local s = Json.number_text(n)
	if s:find("e-", 1, true) then return 6 end
	local after = s:match("%.(.*)$")
	return after and #after or 0
end

-- A number as shown and written: the decimals of the step, up to 3 for a hand edit off the grid; min and max exactly.
function M.format_number(v, row)
	if v == row.min or v == row.max then return Json.number_text(v) end
	local d = math.max(M.decimals(row.step), math.min(3, M.decimals(v)))
	return Json.number_text(tonumber(M.to_fixed(v, d)) + 0.0)
end

local function lower_trim(v)
	return Text.trim(M.js_string(v)):lower()
end

local function num(v)
	local t = lower_trim(v):gsub(",", ".", 1):gsub("^x", "")
	return t:match(NUMBER) and M.js_number(t) or 0 / 0
end

-- The option among those matching f, when only one does.
local function only(options, f)
	local hit = nil
	for i, o in ipairs(options) do
		if f(o) then
			if hit then return nil end
			hit = i
		end
	end
	return hit
end

-- The place of raw among a choice's options: the same value, the same text, the same number ("2.0", "x2", "2,0"), or
-- the same switch word between two switch words; nil when none, or more than one, matches.
function M.option_index(options, raw)
	if raw == nil then return nil end
	for i, o in ipairs(options) do
		if o.value == raw then return i end
	end
	local exact = Text.trim(M.js_string(raw))
	local r = exact:lower()
	local i = only(options, function(o) return M.js_string(o.value) == exact end)
		or only(options, function(o) return M.js_string(o.value):lower() == r end)
	local n = num(r)
	if i == nil and finite(n) then i = only(options, function(o) return num(o.value) == n end) end
	-- An option's own text is not trimmed here, as in Mods Menu.
	local function word(o) return BOOL[M.js_string(o.value):lower()] end
	if i == nil and BOOL[r] ~= nil and #options == 2 and word(options[1]) ~= nil and word(options[2]) ~= nil then
		i = only(options, function(o) return word(o) == BOOL[r] end)
	end
	return i
end

-- A row's value from the file's raw value (nil: the key is absent), or nil where the raw value cannot serve. json: the
-- value comes from JSON, not from a text; a choice keeps a JSON value no option matches.
function M.from_raw(row, raw, json)
	if raw == nil then return nil end
	if row.type == "toggle" then
		if type(raw) == "boolean" then return raw end
		return BOOL[lower_trim(raw)]
	end
	if row.type == "number" then
		local n = raw
		if type(raw) ~= "number" then
			n = M.js_number((Text.trim(M.js_string(raw)):gsub(",", ".", 1):gsub("^[xX]", "")))
		end
		if not finite(n) or Text.trim(M.js_string(raw)) == "" then return nil end
		return n
	end
	if row.type == "choice" then
		local i = M.option_index(row.options, raw)
		if i then return row.options[i].value end
		return json and raw or Text.trim(M.js_string(raw))
	end
	return raw
end

-- The value as written in a config: a toggle as true or false, a number as shown.
function M.to_file(row, v)
	if row.type == "toggle" then return v == true end
	if row.type == "number" then return tonumber(M.format_number(v, row)) + 0.0 end
	return v
end

-- A number without float noise; the ends stay exact.
function M.tidy(row, v)
	if v == row.min or v == row.max then return v end
	return tonumber(M.to_fixed(v, M.decimals(row.step) + 2)) + 0.0
end

-- The next value one step left (dir -1) or right (+1). wrap: a choice goes round, a number goes from one end to the
-- other. A number off the step grid (a hand edit) goes to the nearest grid value that way; one past an end stays.
function M.step(row, v, dir, wrap)
	if row.type == "toggle" then return not v end
	if row.type == "choice" then
		local n = #row.options
		local i = M.option_index(row.options, v)
		local j = (i and i - 1 or (dir > 0 and -1 or n)) + dir
		if j < 0 or j >= n then j = wrap and (j + n) % n or math.min(n - 1, math.max(0, j)) end
		return row.options[j + 1].value
	end
	if row.type ~= "number" then return v end
	local min, max, step = row.min, row.max, row.step
	if (dir < 0 and min ~= nil and v < min) or (dir > 0 and max ~= nil and v > max) then return v end
	local k = v / step
	local near = math.abs(k - round(k)) < 1e-6
	local next = (near and round(k) + dir or (dir > 0 and math.ceil(k) or math.floor(k))) * step
	if max ~= nil and next > max + 1e-9 then next = (wrap and min ~= nil) and min or max end
	if min ~= nil and next < min - 1e-9 then next = (wrap and max ~= nil) and max or min end
	return M.tidy(row, next)
end

-- Where a value sits on a bar, 0 to 1: a number between min and max, a choice by its option's place.
function M.fraction(row, v)
	local f
	if row.type == "number" then
		f = (v - row.min) / (row.max - row.min)
	else
		f = ((M.option_index(row.options, v) or 0) - 1) / (#row.options - 1)
	end
	return math.min(1, math.max(0, f))
end

-- The value at fraction f of a bar: a number on the step grid, min and max kept as stops; or the nearest option.
function M.at_fraction(row, f)
	f = math.min(1, math.max(0, f))
	if row.type == "choice" then return row.options[round(f * (#row.options - 1)) + 1].value end
	local raw = row.min + f * (row.max - row.min)
	local best = round(raw / row.step) * row.step
	for _, stop in ipairs({ row.min, row.max }) do
		if math.abs(raw - stop) < math.abs(raw - best) then best = stop end
	end
	return M.tidy(row, best)
end

return M
