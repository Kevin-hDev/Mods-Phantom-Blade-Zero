-- The controller's buttons as the engine names them (Unreal 5.7, InputCoreTypes.cpp), the game's own Create (PadProbe
-- pass 4, verified in game) and the right stick's directions, each with what a PlayStation and an Xbox controller show,
-- and its icon texture for each when the game has one in memory: ModPanelIcons listed them in the game (discovery 20,
-- releves/mod-panel/2026-11-07-essai-0.2.1). The PlayStation icons are of the family GamepadPS4/V2, the only one with
-- Square and R3; Create has only an older one. No Xbox icon is known for Create, the touchpad or a stick's direction.
-- The left stick's directions are named here but read from its axes (mod_panel_stick.lua, D86). The sticks' and
-- triggers' axes, which the game maps but which are no buttons. Taken from PadProbe's pad_probe_keys.lua (KEYS, MORE)
-- and pad_probe_swallow.lua (AXES). A name that is a word has its other languages in their files (mod_panel_langs.lua,
-- id "<engine name>.<PlayStation|Xbox>"); the others (L1, RB...) are the same in every language.

local Langs = require("mod_panel_langs")

local M = {}

M.CREATE = "PBZ_Gamepad_Create"
M.CROSS = "Gamepad_FaceButton_Bottom"
M.NONE = "None"
-- Buttons read as "just pressed" in the open panel too (mod_panel_pad.lua): a press of Create lasts about 10 ms
-- (PadProbe), less than a frame, and read as held it could fall between two reads (D85).
M.SHORT = { [M.CREATE] = true }
M.PLAYSTATION, M.XBOX = "PlayStation", "Xbox"
local ICONS = "/Game/PBZContent/UI/Foundation/Platform/Input/"
local PS, XB = "GamepadPS4/V2/T_", "GamepadXboxOne/T_XB1_"

-- { engine name, PlayStation's name, Xbox's name, PlayStation icon, Xbox icon }.
M.BUTTONS = {
	{ M.CREATE, "Create", "Create", "GamepadPS4/T_PS4_Share", nil },
	{ "Gamepad_Special_Left", "Touchpad", "View", nil, nil },
	{ "Gamepad_Special_Right", "Options", "Menu", nil, nil },
	{ "Gamepad_FaceButton_Bottom", "Cross", "A", PS .. "Cross", XB .. "A" },
	{ "Gamepad_FaceButton_Right", "Circle", "B", PS .. "Circle", XB .. "B" },
	{ "Gamepad_FaceButton_Left", "Square", "X", PS .. "Square", XB .. "X" },
	{ "Gamepad_FaceButton_Top", "Triangle", "Y", PS .. "Triangle", XB .. "Y" },
	{ "Gamepad_LeftShoulder", "L1", "LB", PS .. "L1", XB .. "LB" },
	{ "Gamepad_RightShoulder", "R1", "RB", PS .. "R1", XB .. "RB" },
	{ "Gamepad_LeftTrigger", "L2", "LT", PS .. "L2", XB .. "LT" },
	{ "Gamepad_RightTrigger", "R2", "RT", PS .. "R2", XB .. "RT" },
	{ "Gamepad_LeftThumbstick", "L3", "LS", PS .. "LStick_Press", XB .. "LStick_Press" },
	{ "Gamepad_RightThumbstick", "R3", "RS", PS .. "RStick_Press", XB .. "RStick_Press" },
	{ "Gamepad_DPad_Up", "D-pad up", "D-pad up", PS .. "DPad_Up", XB .. "DPad_Up" },
	{ "Gamepad_DPad_Down", "D-pad down", "D-pad down", PS .. "DPad_Down", XB .. "DPad_Down" },
	{ "Gamepad_DPad_Left", "D-pad left", "D-pad left", PS .. "DPad_Left", XB .. "DPad_Left" },
	{ "Gamepad_DPad_Right", "D-pad right", "D-pad right", PS .. "DPad_Right", XB .. "DPad_Right" },
	{ "Gamepad_LeftStick_Up", "Left stick up", "Left stick up", nil, nil },
	{ "Gamepad_LeftStick_Down", "Left stick down", "Left stick down", nil, nil },
	{ "Gamepad_LeftStick_Left", "Left stick left", "Left stick left", nil, nil },
	{ "Gamepad_LeftStick_Right", "Left stick right", "Left stick right", nil, nil },
	{ "Gamepad_RightStick_Up", "Right stick up", "Right stick up", nil, nil },
	{ "Gamepad_RightStick_Down", "Right stick down", "Right stick down", nil, nil },
	{ "Gamepad_RightStick_Left", "Right stick left", "Right stick left", nil, nil },
	{ "Gamepad_RightStick_Right", "Right stick right", "Right stick right", nil, nil },
}
M.AXES = { "Gamepad_Left2D", "Gamepad_Right2D", "Gamepad_LeftX", "Gamepad_LeftY", "Gamepad_RightX", "Gamepad_RightY",
	"Gamepad_LeftTriggerAxis", "Gamepad_RightTriggerAxis" }

-- The path StaticFindObject takes for an icon under ICONS, made once here rather than at each frame.
local function path(file)
	return file and ICONS .. file .. "." .. file:match("([^/]+)$") or nil
end

local by_name = {}
for _, b in ipairs(M.BUTTONS) do
	by_name[b[1]] = { [M.PLAYSTATION] = { b[2], path(b[4]), b[1] .. "." .. M.PLAYSTATION },
		[M.XBOX] = { b[3], path(b[5]), b[1] .. "." .. M.XBOX } }
end

-- Whether name is one of the buttons above.
function M.known(name)
	return by_name[name] ~= nil
end

-- What brand's controller (PlayStation's when nil) shows for a button, in lang (one of mod_panel_text.lua's LANGS);
-- the engine's name for a key this table does not hold.
function M.label(name, brand, lang)
	local b = by_name[name]
	if b == nil then return tostring(name) end
	local own = b[brand] or b[M.PLAYSTATION]
	return Langs.get("buttons", own[3], lang) or own[1]
end

-- The path of a button's icon texture for brand, as StaticFindObject takes it, or nil when none is known.
function M.icon(name, brand)
	local b = by_name[name]
	return b and (b[brand] or b[M.PLAYSTATION])[2]
end

return M
