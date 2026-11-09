-- The buttons a player may pick for toggle sprint (Kevin, 9 November 2026: a button picked in the menu, none by
-- default), by the engine's key names, as IsInputKeyDown reads them. Mods Menu lets only its own rows listen for a key,
-- so each row is a list. make_menu.py gives each name its label; test_movement_tuning.py checks the menu lists the same
-- names in the same order.

local M = {}

M.NONE = "None"

M.PAD = {
	M.NONE,
	"Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right", "Gamepad_FaceButton_Left", "Gamepad_FaceButton_Top",
	"Gamepad_LeftShoulder", "Gamepad_RightShoulder", "Gamepad_LeftTrigger", "Gamepad_RightTrigger",
	"Gamepad_LeftThumbstick", "Gamepad_RightThumbstick",
	"Gamepad_DPad_Up", "Gamepad_DPad_Down", "Gamepad_DPad_Left", "Gamepad_DPad_Right",
}

-- No digits: on an AZERTY keyboard the top row gives other key names ("Ampersand" for 1), so they would not work.
M.KEYBOARD = {
	M.NONE,
	"LeftShift", "SpaceBar", "LeftControl", "LeftAlt", "Tab", "CapsLock", "RightShift", "RightControl", "RightAlt",
	"LeftMouseButton", "RightMouseButton", "MiddleMouseButton", "ThumbMouseButton", "ThumbMouseButton2",
}
for c = string.byte("A"), string.byte("Z") do M.KEYBOARD[#M.KEYBOARD + 1] = string.char(c) end

M.TOGGLE_PAD = { key = "ToggleSprintButton", options = M.PAD, default = M.NONE }
M.TOGGLE_KEY = { key = "ToggleSprintKey", options = M.KEYBOARD, default = M.NONE }

-- The engine's key for a name ({ KeyName = FName }), made once per name; nil when FName fails.
local keys = {}
function M.key(name)
	if keys[name] == nil then
		local ok, fname = pcall(function() return FName(name) end)
		if ok and fname ~= nil then keys[name] = { KeyName = fname } end
	end
	return keys[name]
end

return M
