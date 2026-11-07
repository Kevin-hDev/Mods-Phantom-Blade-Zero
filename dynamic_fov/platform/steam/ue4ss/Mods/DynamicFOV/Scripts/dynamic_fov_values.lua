-- How one value of the settings file becomes the one the mod uses (dynamic_fov_settings.lua says which key is which):
-- a missing value gives its default, a wrong one its default and a line in UE4SS.log, a number out of range is brought
-- back into it. The menu writes each value as the mod wants it; a hand edit may change its case, add spaces, or write
-- a switch or a number as text.

local M = {}

-- No setting value is this long: a longer one is refused before trimming, whose pattern takes time growing with the
-- square of a long run of spaces (a hand edit could freeze the game for seconds, crash audit of 4 November 2026).
local MAX_VALUE_LENGTH = 64

-- A hand edit may write a switch as text, or as the number 0 or 1.
local BOOLEANS = { ["true"] = true, yes = true, on = true, ["1"] = true,
	["false"] = false, no = false, off = false, ["0"] = false }

function M.trim(s)
	if #s > MAX_VALUE_LENGTH then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A value on its step, as the menu keeps it: whole steps give whole numbers, and a tenth is counted in tenths, so
-- 1.2 stays 1.2 and is written so in the file, not 1.2000000000000002 (twelve times 0.1).
function M.snap(value, step)
	if step >= 1 then return math.floor(value / step + 0.5) * step end
	local per_unit = math.floor(1 / step + 0.5)
	return math.floor(value * per_unit + 0.5) / per_unit
end

function M.switch(raw, key, name, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then
		value = BOOLEANS[M.trim(value):lower()]
	elseif value == 0 or value == 1 then
		value = value == 1
	end
	if type(value) == "boolean" then return value end
	warn(string.format("%s must be true or false; using %s", name, tostring(default)))
	return default
end

-- Brought onto the menu's step, then into range.
function M.number(raw, key, name, default, low, high, step, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then value = tonumber(M.trim(value)) end
	if type(value) ~= "number" or value ~= value then
		warn(string.format("%s must be a number from %s to %s; using %s", name, low, high, default))
		return default
	end
	local rounded = M.snap(value, step)
	local kept = math.max(low, math.min(high, rounded))
	if math.abs(kept - rounded) > 1e-9 then
		warn(string.format("%s must be from %s to %s; using %s", name, low, high, kept))
	end
	return kept
end

-- One of options (the menu's spellings), matched without case nor spaces ("very close" is VeryClose); a whole number
-- is read as its digits ("140" or 140). A number with no integer form (1e30, inf) falls to the warning: formatted with
-- %d it raised, and the whole file was not read (audit of 6 November 2026).
function M.choice(raw, key, name, options, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "number" then value = math.tointeger(value) and tostring(math.tointeger(value)) or value end
	if type(value) == "string" then
		local wanted = M.trim(value):gsub("%s", ""):lower()
		for _, o in ipairs(options) do
			if o:lower() == wanted then return o end
		end
	end
	local list = #options == 1 and options[1]
		or table.concat(options, ", ", 1, #options - 1) .. " or " .. options[#options]
	warn(string.format("%s must be %s; using %s", name, list, default))
	return default
end

return M
