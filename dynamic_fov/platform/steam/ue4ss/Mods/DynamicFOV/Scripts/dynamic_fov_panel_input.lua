-- The controls while the panel is open. With the panel's input context on (dynamic_fov_panel_context.lua, 1.0.5), the
-- inputs go to the game and the panel: the context takes every key from the game, and the panel reads the controller
-- (verified in game). Without it, to the panel only, with no widget focused, as until 1.0.4,
-- so the character stands still and Escape does not open the game's menu (MouseProbe and PanelProbe, verified in game
-- on 4 November 2026); but then no key reaches the player controller, so no controller button can be read (Unreal 5.7:
-- FInputModeUIOnly sets IgnoreInput). Either way the cursor shows, and stays in the game's
-- window as in the game's own menus (LockAlways: the engine locks it only while the window is in front and frees it at
-- the Windows key, Unreal 5.7, SlateUser.cpp and SlateApplication.cpp), also during a click on the game
-- (bHideCursorDuringCapture off). The game turns the cursor off by itself (MouseProbe pass 2): it is turned back on at
-- each frame, and the panel's input mode set again, which the game has then replaced (it had freed the mouse,
-- PanelProbe pass 4).
-- Each change of input mode lets go of the keys held (bFlushInput): with the inputs the panel's, the game never hears
-- a key let go, and a character walking when the panel opened would walk on (Unreal 5.7, WidgetBlueprintLibrary.cpp
-- and PlayerInput.cpp; audit of 5 November 2026).

local U = require("dynamic_fov_unreal")
local PanelCalls = require("dynamic_fov_panel_calls")

local M = {}

local LIBRARY = PanelCalls.UMG .. "Default__WidgetBlueprintLibrary"
local LOCK_ALWAYS = 2             -- EMouseLockMode
local REAPPLY_GAP = 30            -- frames between two settings of the input mode, should the game fight every frame
local MAX_CURSOR_LINES = 20

-- both: the open panel's mode lets the game's inputs through, its context taking them.
local S = { lib = nil, frames = 0, reapplied = 0, cursor_off = 0, both = false }

-- Named functions for pcall.
local function panel_only(lib, pc) lib:SetInputMode_UIOnlyEx(pc, nil, LOCK_ALWAYS, true) end
local function game_and_panel(lib, pc) lib:SetInputMode_GameAndUIEx(pc, nil, LOCK_ALWAYS, false, true) end
local function game_only(lib, pc) lib:SetInputMode_GameOnly(pc, true) end
local function show_cursor(pc, on) pc.bShowMouseCursor = on end
local function cursor_shown(pc) return pc.bShowMouseCursor end

local function library()
	if not U.is_valid(S.lib) then
		local ok, lib = pcall(StaticFindObject, LIBRARY)
		S.lib = ok and lib or nil
	end
	return U.is_valid(S.lib) and S.lib or nil
end

-- The inputs to the open panel (set, one of the two modes above), or back to the game. report(fmt, ...) hears of a
-- failure.
local function mode(pc, set, report)
	local lib = library()
	if lib == nil then
		report("panel: the input mode cannot be set, the engine's widget library is not found")
		return
	end
	local ok, err = pcall(set, lib, pc)
	if not ok then report("panel: the input mode could not be set (%s)", tostring(err)) end
end

local function open_mode() return S.both and game_and_panel or panel_only end

local function cursor(pc, on, report)
	local ok, err = pcall(show_cursor, pc, on)
	if not ok then report("panel: the cursor could not be %s (%s)", on and "shown" or "hidden", tostring(err)) end
end

-- At the panel's opening: its inputs and the cursor. both: the panel's input context is on.
function M.take(pc, report, both)
	S.frames, S.reapplied, S.both = 0, 0, both == true
	mode(pc, open_mode(), report)
	cursor(pc, true, report)
end

-- At its closing: the game's inputs back, the cursor off.
function M.give_back(pc, report)
	mode(pc, game_only, report)
	cursor(pc, false, report)
end

-- At each frame while it is open. The game turning the cursor off is its way, not a failure (seen in game 11 times in
-- 5 minutes): said with the panel's routine lines (report), the failures to set it back with its failures (problem).
function M.keep(pc, report, problem)
	S.frames = S.frames + 1
	local ok, shown = pcall(cursor_shown, pc)
	if not ok or shown ~= false then return end
	S.cursor_off = S.cursor_off + 1
	if S.cursor_off <= MAX_CURSOR_LINES then
		report("panel: the game turned the cursor off (#%d): turned back on", S.cursor_off)
	end
	cursor(pc, true, problem)
	if S.frames - S.reapplied >= REAPPLY_GAP then
		S.reapplied = S.frames
		mode(pc, open_mode(), problem)
	end
end

return M
