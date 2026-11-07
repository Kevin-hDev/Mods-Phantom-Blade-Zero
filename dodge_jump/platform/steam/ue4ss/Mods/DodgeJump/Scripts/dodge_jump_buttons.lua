-- The buttons the player may pick in the settings, by the engine's key names, as UE4SS reads them with IsInputKeyDown.
-- Players who move the game's dodge or jump to other buttons with a remapping tool pick them here (design decision,
-- 4 November 2026): the mod cannot read the game's own buttons (IA_Jump lists no keys, dodge enquiry of 3 November
-- 2026). Mods Menu lets only its own rows listen for a key (PBZModsMenu main.js 0.5.0, "built-in" capture rows),
-- so each row is a list.
-- DodgeJump.modsmenu.json lists the same names, in the same order, with their labels: test_dodge_jump.py checks it.

local M = {}

M.PAD = {
	"Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right", "Gamepad_FaceButton_Left", "Gamepad_FaceButton_Top",
	"Gamepad_LeftShoulder", "Gamepad_RightShoulder", "Gamepad_LeftTrigger", "Gamepad_RightTrigger",
	"Gamepad_LeftThumbstick", "Gamepad_RightThumbstick",
	"Gamepad_DPad_Up", "Gamepad_DPad_Down", "Gamepad_DPad_Left", "Gamepad_DPad_Right",
}

-- No digits: on an AZERTY keyboard the top row gives other key names ("Ampersand" for 1), so they would not work.
M.KEYBOARD = {
	"LeftShift", "SpaceBar", "LeftControl", "LeftAlt", "Tab", "CapsLock", "RightShift", "RightControl", "RightAlt",
	"LeftMouseButton", "RightMouseButton", "MiddleMouseButton", "ThumbMouseButton", "ThumbMouseButton2",
}
for c = string.byte("A"), string.byte("Z") do M.KEYBOARD[#M.KEYBOARD + 1] = string.char(c) end

-- The four rows: the air jump's buttons (the game's dodge by default, which leaves the jump free for other mods), then
-- the game's jump, the button whose early presses are kept (dodge_jump_landing.lua).
M.ROWS = {
	{ name = "AirJumpButton", list = M.PAD, default = "Gamepad_RightShoulder" },
	{ name = "AirJumpKey", list = M.KEYBOARD, default = "LeftShift" },
	{ name = "JumpButton", list = M.PAD, default = "Gamepad_FaceButton_Bottom" },
	{ name = "JumpKey", list = M.KEYBOARD, default = "SpaceBar" },
}
M.AIR_PAD, M.AIR_KEY, M.JUMP_PAD, M.JUMP_KEY = M.ROWS[1], M.ROWS[2], M.ROWS[3], M.ROWS[4]

-- Each row's names by their lowercase spelling: a hand edit may change the case.
for _, row in ipairs(M.ROWS) do
	row.known = {}
	for _, name in ipairs(row.list) do row.known[name:lower()] = name end
end

return M
