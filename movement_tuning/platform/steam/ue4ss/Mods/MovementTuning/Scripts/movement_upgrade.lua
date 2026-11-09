-- Settings files from before 1.0.3 have AutoSprint (true or false) where 1.0.3 has SprintMode (Game, Auto or Toggle,
-- movement_sprint_settings.lua). Mods Menu shows a key it has no row for as a row of its own that cannot be changed
-- (seen in game, 8 November 2026), so the key is replaced in the file, everything else kept as it was: on (or a value
-- that cannot be read, as the settings read it: auto sprint's default) gives Auto, off gives Game.

local M = {}

local OLD, NEW = "autosprint", "SprintMode"

-- raw: the file's keys, lowercased; on: whether the old key reads as on. Returns the new text, or nil when the file
-- needs nothing or the key cannot be found in the text.
function M.new_text(text, raw, on)
	if raw[NEW:lower()] ~= nil or raw[OLD] == nil then return nil end
	-- Lowercasing keeps every byte where it was: the positions found in it hold in the text.
	local low = text:lower()
	local first, last = low:find('"' .. OLD .. '"%s*:%s*')
	if first == nil then return nil end
	local _, value_end = text:find('^"[^"]*"', last + 1)
	if value_end == nil then _, value_end = text:find("^[%w%.%-]+", last + 1) end
	if value_end == nil then return nil end
	return text:sub(1, first - 1) .. string.format('"%s": "%s"', NEW, on and "Auto" or "Game") .. text:sub(value_end + 1)
end

return M
