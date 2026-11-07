-- Reading one value of the settings file: a switch, a number on the menu's steps, a choice among words. Tolerant: a
-- missing value gives the default, a wrong one the default with a warning for UE4SS.log.

local M = {}

local MAX_VALUE_LENGTH = 64
local BOOLEANS = { ["true"] = true, yes = true, on = true, ["1"] = true,
	["false"] = false, no = false, off = false, ["0"] = false }

-- A longer value is refused before trimming, whose pattern takes time growing with the square of a run of spaces.
function M.trim(s)
	if #s > MAX_VALUE_LENGTH then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.word(value)
	return type(value) == "string" and M.trim(value):lower() or nil
end

-- A value on hundredths as the menu writes it: one decimal on a tenth ("1.3", as files written before 1.0.1 hold),
-- two otherwise ("1.35").
function M.show(n)
	local hundredths = math.floor(n * 100 + 0.5)
	if hundredths % 10 == 0 then return string.format("%.1f", hundredths / 100) end
	return string.format("%.2f", hundredths / 100)
end

function M.switch(raw, key, name, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then
		value = BOOLEANS[M.word(value)]
	elseif value == 0 or value == 1 then
		value = value == 1
	end
	if type(value) == "boolean" then return value end
	warn(string.format("%s must be true or false; using %s", name, tostring(default)))
	return default
end

local function on_step(n, step)
	if step >= 1 then return math.floor(n / step + 0.5) * step end
	return math.floor(n / step + 0.5) / (1 / step)
end

-- A number or a number in text from entry.min to entry.max, on the menu's steps; nil for anything else.
function M.in_range(value, entry)
	if type(value) == "string" then value = tonumber(M.trim(value)) end
	if type(value) ~= "number" or value ~= value or value < entry.min or value > entry.max then return nil end
	return on_step(value, entry.step)
end

function M.ranged(raw, entry, default, warn)
	local value = raw[entry.key:lower()]
	if value == nil then return default end
	local n = M.in_range(value, entry)
	if n ~= nil then return n end
	warn(string.format("%s must be %g to %g; using %g", entry.key, entry.min, entry.max, default))
	return default
end

function M.choice(raw, key, options, default, warn)
	local value = raw[key:lower()]
	if value == nil then return default end
	local w = M.word(value)
	for _, option in ipairs(options) do
		if w == option:lower() then return option end
	end
	warn(string.format("%s must be %s; using %s", key, table.concat(options, ", "), default))
	return default
end

return M
