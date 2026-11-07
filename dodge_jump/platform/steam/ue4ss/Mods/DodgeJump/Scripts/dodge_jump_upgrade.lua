-- Settings files written by Dodge Jump 1.0.0 and 1.0.1, which had one Button row for the air jump, Dodge or Jump.
-- 1.0.2 has a controller row and a keyboard row instead (dodge_jump_buttons.lua). Dodge is what the new rows give by
-- default, so its files need nothing. A file with Button Jump gets the two new rows, set to the game's jump buttons:
-- Mods Menu shows a row's value from the file, so without them it would show R1 while the air jump is on Cross.
-- The Button key stays in the file: the menu keeps the keys it has no row for, and the mod reads it only here.

local Buttons = require("dodge_jump_buttons")

local M = {}

-- raw: the file's keys, lowercased; word: a value as the settings compare it (trimmed, lowercase, nil if not text).
-- Returns the file's text with the two rows added after its opening brace, everything else kept as it was, or nil
-- when the file needs nothing.
function M.new_text(text, raw, word)
	if raw[Buttons.AIR_PAD.name:lower()] ~= nil or raw[Buttons.AIR_KEY.name:lower()] ~= nil then return nil end
	if word(raw.button) ~= "jump" then return nil end
	-- A file with a Button key is an object with at least that member, so the added rows end with a comma.
	local open = text:find("{", 1, true)
	if open == nil then return nil end
	local rows = string.format('\r\n  "%s": "%s",\r\n  "%s": "%s",', Buttons.AIR_PAD.name, Buttons.JUMP_PAD.default,
		Buttons.AIR_KEY.name, Buttons.JUMP_KEY.default)
	return text:sub(1, open) .. rows .. text:sub(open + 1)
end

return M
