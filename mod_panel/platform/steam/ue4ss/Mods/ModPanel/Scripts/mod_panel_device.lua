-- The device in use and the controller's name, as the game's CommonInput subsystem tells them: the name for the icons
-- in Auto (D73), the device for the open panel's input mode (D128), the one CommonUI goes by when it makes Cross a
-- mouse click (discovery 24). The subsystem is asked of the controller once at each opening (D68) and kept: the
-- engine keeps it as long as the local player, and it is checked valid at each use.

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")

local M = {}

local GAMEPAD = 1                 -- ECommonInputType (CommonInputTypeEnum.h)

local S = { sub = nil }

-- Named functions for pcall.
local function name_of(sub) return sub:GetCurrentGamepadName() end
local function type_of(sub) return sub:GetCurrentInputType() end

-- At each opening, before the panel's first paint, on its controller pc.
function M.start(pc)
	local wanted = Calls.ok(Calls.GAMEPAD_NAME) or Calls.ok(Calls.INPUT_TYPE)
	S.sub = wanted and Calls.ok(Calls.FROM_PC) and U.subsystem(pc, Calls.COMMON_INPUT) or nil
end

-- The controller's name the game gives, or nil.
function M.gamepad_name()
	if not (Calls.ok(Calls.GAMEPAD_NAME) and U.is_valid(S.sub)) then return nil end
	local ok, name = pcall(name_of, S.sub)
	return ok and U.text(name) or nil
end

-- Whether the controller is the device in use, or nil and why it cannot be read.
function M.pad_in_use()
	if not Calls.ok(Calls.INPUT_TYPE) then return nil, "the engine's function is not the one this version knows" end
	if not U.is_valid(S.sub) then return nil, "the game's input subsystem is not given" end
	local ok, t = pcall(type_of, S.sub)
	local n = ok and U.num(t) or nil
	if n == nil then return nil, ok and "unreadable" or tostring(t) end
	return n == GAMEPAD
end

return M
