-- How Mod Panel runs: every frame of the player controller, from a hook on its blueprint's ReceiveTick. Taken from
-- Dynamic FOV 1.0.4 (dynamic_fov_driver.lua). UE4SS runs a blueprint hook's Lua, a NotifyOnNewObject callback's and
-- a key bind's under one lock (script_hook and the construct callbacks in LuaMod.cpp, UE4SS 1ceefac), but not the
-- Lua of LoopInGameThreadWithDelay, ExecuteInGameThread or a hook on a native function such as ClientRestart. Since the
-- key binds run on UE4SS's own thread (mod_panel_keys.lua), the mod's Lua runs only where that lock is held: two
-- threads in one Lua state can crash the game (crash audit, 4 November 2026).
--
-- The blueprint is not loaded when mods start: the hook is set once a player controller is made, from the
-- NotifyOnNewObject callback (or at start, when the blueprint is already there). Each controller made is a load.

local M = {}

M.CONTROLLER_CLASS = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController.BP_PlayerController_C"
M.CONTROLLER_TICK = M.CONTROLLER_CLASS .. ":ReceiveTick"

-- frame(param): every frame of the player controller, param the hook's controller (param:get() gives it).
-- new_controller(): a player controller was made. What cannot be set is said in the log.
function M.start(frame, new_controller, log)
	local hooked = false
	local function hook(when)
		if hooked then return end
		local ok, err = pcall(RegisterHook, M.CONTROLLER_TICK, frame)
		hooked = ok
		if ok then
			log("runs with the player controller's tick (hooked %s)", when)
		elseif when ~= "at start" then
			log("the player controller's tick cannot be hooked yet (%s)", tostring(err))
		end
	end
	hook("at start")
	local ok, err = pcall(NotifyOnNewObject, M.CONTROLLER_CLASS, function()
		new_controller()
		hook("when a player controller was made")
	end)
	if not ok and not hooked then
		log("cannot watch for the player, the mod stays off (%s)", tostring(err))
	elseif not ok then
		log("cannot hear of new player controllers (%s)", tostring(err))
	end
end

return M
