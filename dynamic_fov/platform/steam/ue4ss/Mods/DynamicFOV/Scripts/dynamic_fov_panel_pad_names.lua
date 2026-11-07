-- The controller's buttons and axes as the engine names them (Unreal 5.7, InputCoreTypes.cpp), the game's own Create
-- (PadProbe pass 4, verified in game) included: the panel's input context takes them all, so the game hears none while
-- the panel is open (dynamic_fov_panel_context.lua). Of them the panel reads only the D-pad, Cross, Triangle and
-- Circle, and the left stick by its axes (dynamic_fov_panel_pad.lua). Triangle's and Circle's names and icons for a
-- PlayStation and an Xbox controller: the four icons found in the game's memory (verified in game, 7 November 2026).

local M = {}

M.PLAYSTATION, M.XBOX = "PlayStation", "Xbox"
M.CROSS, M.CIRCLE, M.TRIANGLE = "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right", "Gamepad_FaceButton_Top"
M.UP, M.DOWN, M.LEFT, M.RIGHT = "Gamepad_DPad_Up", "Gamepad_DPad_Down", "Gamepad_DPad_Left", "Gamepad_DPad_Right"
-- Read from the left stick's axes, never as buttons: the game's interface takes their presses first (verified in
-- game).
M.STICK_UP, M.STICK_DOWN = "Gamepad_LeftStick_Up", "Gamepad_LeftStick_Down"
M.STICK_LEFT, M.STICK_RIGHT = "Gamepad_LeftStick_Left", "Gamepad_LeftStick_Right"

M.BUTTONS = { "PBZ_Gamepad_Create", "Gamepad_Special_Left", "Gamepad_Special_Right", M.CROSS, M.CIRCLE,
	"Gamepad_FaceButton_Left", M.TRIANGLE, "Gamepad_LeftShoulder", "Gamepad_RightShoulder", "Gamepad_LeftTrigger",
	"Gamepad_RightTrigger", "Gamepad_LeftThumbstick", "Gamepad_RightThumbstick", M.UP, M.DOWN, M.LEFT, M.RIGHT,
	M.STICK_UP, M.STICK_DOWN, M.STICK_LEFT, M.STICK_RIGHT, "Gamepad_RightStick_Up", "Gamepad_RightStick_Down",
	"Gamepad_RightStick_Left", "Gamepad_RightStick_Right" }
M.AXES = { "Gamepad_Left2D", "Gamepad_Right2D", "Gamepad_LeftX", "Gamepad_LeftY", "Gamepad_RightX", "Gamepad_RightY",
	"Gamepad_LeftTriggerAxis", "Gamepad_RightTriggerAxis" }

local ICONS = "/Game/PBZContent/UI/Foundation/Platform/Input/"

-- The path StaticFindObject takes for an icon under ICONS.
local function path(file)
	return ICONS .. file .. "." .. file:match("([^/]+)$")
end

-- The two buttons shown on the panel's buttons: { name, icon } for each brand, and the Chinese name of a word.
local SHOWN = {
	[M.TRIANGLE] = { [M.PLAYSTATION] = { "Triangle", path("GamepadPS4/V2/T_Triangle"), "△键" },
		[M.XBOX] = { "Y", path("GamepadXboxOne/T_XB1_Y") } },
	[M.CIRCLE] = { [M.PLAYSTATION] = { "Circle", path("GamepadPS4/V2/T_Circle"), "○键" },
		[M.XBOX] = { "B", path("GamepadXboxOne/T_XB1_B") } },
}
M.BRANDS = { M.PLAYSTATION, M.XBOX }

-- Whose icons for the controller's name the game gives ("PS5" for a DualSense; nil when unknown).
function M.brand_of(gamepad)
	if type(gamepad) == "string" and gamepad:sub(1, 2) == "PS" then return M.PLAYSTATION end
	return M.XBOX
end

-- Button's name on brand's controller, in lang ("en", "zh-Hans"...). The panel has no traditional Chinese texts and
-- shows English there: the English name then, not simplified characters before an English word (audit of 1.0.5).
function M.label(button, brand, lang)
	local own = SHOWN[button][brand]
	if lang == "zh-Hans" and own[3] ~= nil then return own[3] end
	return own[1]
end

-- The path of button's icon on brand's controller.
function M.icon(button, brand)
	return SHOWN[button][brand][2]
end

return M
