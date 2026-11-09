-- The controls while the panel is open. With Mod Panel's input context on (mod_panel_context.lua, D66), the inputs go
-- to the game and the panel: the context takes every key from the game, and the panel reads the controller. Without
-- it, to the panel only, with no widget focused, as in 0.2.0, so the character stands still and Escape does not open
-- the game's menu (MouseProbe and PanelProbe, verified in game on 4 November 2026); but then no key reaches the player
-- controller, so no controller button can be read (Unreal 5.7: FInputModeUIOnly sets IgnoreInput, and
-- UGameViewportClient::InputKey stops before the player; discovery 18).
-- With the context, the mode follows the device in use (mod_panel_device.lua, D128). The controller in use: the
-- game's own mode in play, its view holding the mouse, the cursor hidden. CommonUI makes Cross a left click while the
-- view has the focus without holding the mouse (Unreal 5.7, CommonAnalogCursor.cpp line 571; discovery 24): the first
-- Cross of each opening was lost so (trials of 0.4.5 and 0.4.6, verified in game). The keyboard or the mouse in use,
-- and without the context: the cursor shows, and stays in the game's window as in the game's own menus (LockAlways:
-- the engine locks it only while the window is in front and frees it at the Windows key, Unreal 5.7, SlateUser.cpp
-- and SlateApplication.cpp), also during a click on the game (bHideCursorDuringCapture off). The game turns that
-- cursor off by itself (MouseProbe pass 2): it is turned back on at each frame, and the panel's input mode set again,
-- which the game has then replaced (it had freed the mouse, PanelProbe pass 4).
-- The openings, the closings and the panel's mode set again let go of the keys held (bFlushInput): otherwise a
-- character walking when the panel opened would walk on (Unreal 5.7, WidgetBlueprintLibrary.cpp and PlayerInput.cpp;
-- audit of 5 November 2026). A change of device does not: the button that made it would be lost. Taken from Dynamic
-- FOV 1.0.4's dynamic_fov_panel_input.lua.

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")
local Flush = require("mod_panel_flush")
local Mouse = require("mod_panel_mouse")
local Device = require("mod_panel_device")

local M = {}

local LIBRARY = Calls.UMG .. "Default__WidgetBlueprintLibrary"
local LOCK_ALWAYS = 2             -- EMouseLockMode
local REAPPLY_GAP = 30            -- frames between two settings of the input mode, should the game fight every frame
local MAX_CURSOR_LINES = 20

-- both: the open panel's inputs go to the game and the panel, its context taking them. pad: the controller is in use.
-- no_device: why the device in use could not be read, said once until another reason comes.
local S = { lib = nil, frames = 0, reapplied = 0, cursor_off = 0, both = false, pad = false, no_device = nil }

-- Named functions for pcall; flush: the keys held let go.
local function panel_only(lib, pc, flush) lib:SetInputMode_UIOnlyEx(pc, nil, LOCK_ALWAYS, flush) end
local function game_and_panel(lib, pc, flush) lib:SetInputMode_GameAndUIEx(pc, nil, LOCK_ALWAYS, false, flush) end
local function game_only(lib, pc, flush) lib:SetInputMode_GameOnly(pc, flush) end
local function show_cursor(pc, on) pc.bShowMouseCursor = on end
local function cursor_shown(pc) return pc.bShowMouseCursor end

local function library()
	if not U.is_valid(S.lib) then
		local ok, lib = pcall(StaticFindObject, LIBRARY)
		S.lib = ok and lib or nil
	end
	return U.is_valid(S.lib) and S.lib or nil
end

-- The inputs set by set, one of the three modes above. report(fmt, ...) hears of a failure.
local function mode(pc, set, flush, report)
	local lib = library()
	if lib == nil then
		report("panel: the input mode cannot be set, the engine's widget library is not found")
		return
	end
	local ok, err = pcall(set, lib, pc, flush)
	if ok and flush then Flush.mark(os.clock()) end
	if not ok then report("panel: the input mode could not be set (%s)", tostring(err)) end
end

local function open_mode()
	if not S.both then return panel_only end
	return S.pad and game_only or game_and_panel
end

local function cursor(pc, on, report)
	local ok, err = pcall(show_cursor, pc, on)
	if not ok then report("panel: the cursor could not be %s (%s)", on and "shown" or "hidden", tostring(err)) end
end

-- Whether the controller is in use; false when that cannot be read, said once (problem).
local function pad_in_use(problem)
	local pad, why = Device.pad_in_use()
	if pad ~= nil then return pad end
	if why ~= S.no_device then
		S.no_device = why
		problem("panel: the device in use cannot be read (%s): the first Cross of an opening may do nothing", why)
	end
	return false
end

-- At the panel's opening: its inputs and the cursor. both: Mod Panel's input context is on. problem(fmt, ...): the
-- panel's failures.
function M.take(pc, problem, both)
	S.frames, S.reapplied, S.both = 0, 0, both == true
	S.pad = S.both and pad_in_use(problem)
	mode(pc, open_mode(), true, problem)
	cursor(pc, not S.pad, problem)
end

-- At its closing: the game's inputs back, the cursor off.
function M.give_back(pc, report)
	mode(pc, game_only, true, report)
	cursor(pc, false, report)
end

-- Whether the open panel is in the controller's mode at this frame (set by M.take, then M.keep).
function M.pad_mode() return S.pad end

-- Another device in use: the open panel's mode for it.
local function switch(pc, pad, problem)
	S.pad = pad
	mode(pc, open_mode(), false, problem)
	cursor(pc, not pad, problem)
	if not pad then Mouse.rebase() end
end

-- At each frame while it is open, before the controller's commands, which go by its mode (D128). The game turning the
-- cursor off is its way, not a failure (seen in game 11 times in 5 minutes): said with the panel's routine lines
-- (report), the failures to set it back with its failures (problem). Where the cursor comes back is no move of the
-- player's (D100).
function M.keep(pc, report, problem)
	S.frames = S.frames + 1
	if S.both then
		local pad = pad_in_use(problem)
		if pad ~= S.pad then return switch(pc, pad, problem) end
	end
	if S.pad then return end
	local ok, shown = pcall(cursor_shown, pc)
	if not ok or shown ~= false then return end
	S.cursor_off = S.cursor_off + 1
	if S.cursor_off <= MAX_CURSOR_LINES then
		report("panel: the game turned the cursor off (#%d): turned back on", S.cursor_off)
	end
	cursor(pc, true, problem)
	Mouse.rebase()
	if S.frames - S.reapplied >= REAPPLY_GAP then
		S.reapplied = S.frames
		mode(pc, open_mode(), true, problem)
	end
end

return M
