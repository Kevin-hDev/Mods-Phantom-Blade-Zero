-- The buttons the player may pick to slide, by the engine's key names, as UE4SS reads them with IsInputKeyDown. None
-- is picked by default: the player assigns one (Kevin, 5 November 2026: "il n'y aura pas de bouton déjà assigné par
-- défaut, ce sera au joueur d'assigner une touche pour le slide"; Circle was only for our trials). The game has no
-- slide button of its own to read. Mods Menu lets only its own rows listen for a key (Dodge Jump's
-- dodge_jump_buttons.lua), so each row is a list; the lists are Dodge Jump's, with None first.
-- SlideAnywhere.modsmenu.json lists the same names, in the same order, with their labels: test_slide_anywhere.py checks
-- it.

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

M.ROWS = {
	{ name = "SlideButton", list = M.PAD },
	{ name = "SlideKey", list = M.KEYBOARD },
}

-- Each row's names by their lowercase spelling: a hand edit may change the case.
for _, row in ipairs(M.ROWS) do
	row.known = {}
	for _, name in ipairs(row.list) do row.known[name:lower()] = name end
end

return M
