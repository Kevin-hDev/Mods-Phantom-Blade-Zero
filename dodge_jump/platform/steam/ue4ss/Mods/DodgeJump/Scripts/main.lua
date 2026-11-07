-- Dodge Jump for Phantom Blade Zero: double and triple jumps in the air, with the game's own dodge animations, and a
-- jump pressed just before or just after a landing kept until the game takes it, each air jump with a sound of the
-- game's dodges. Settings (Enabled, Chains, the air jumps' speed and sound volume, and the air jump's and the jump's
-- buttons, controller and keyboard) in DodgeJump.config.json in the mod's folder, changed in Mods Menu (Nexus 149)
-- or by hand; read each time a save is loaded, and again within a second of a change saved in the menu.
--
-- The work happens in the player controller's ReceiveTick, as in Tap Strafe and Jump Strafe. Settings and menu
-- handling follow Tap Strafe's main.lua.

local U = require("dodge_jump_unreal")
local Settings = require("dodge_jump_settings")
local Menu = require("dodge_jump_menu")
local Air = require("dodge_jump_air")
local Land = require("dodge_jump_landing")
local Keys = require("dodge_jump_keys")
local Objects = require("dodge_jump_objects")
local Sound = require("dodge_jump_sound")

local VERSION = "1.0.6"
local CONTROLLER_TICK = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController.BP_PlayerController_C:ReceiveTick"
local CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"
local FALLING = 3                 -- EMovementMode::MOVE_Falling: jumps and falls
local STATUS_EVERY = 600          -- seconds between two status lines
local MENU_CHECK_EVERY = 1        -- seconds between two looks at the Mods Menu's event file
local MAX_READ_RETRIES = 5        -- looks spent on a settings file that exists but cannot be read
local MAX_ERROR_LINES = 5         -- a repeated error is written a few times, then only counted
local MOD_DIR = Settings.mod_dir(debug.getinfo(1, "S").source)
local SETTINGS_PATH = MOD_DIR and Settings.file_in(MOD_DIR)
local EVENTS_PATH = MOD_DIR and Menu.events_file(MOD_DIR)

local S = { hooked = false, restarted = false, errors = 0, new_errors = 0, pawn = nil, cmc = nil, in_air = false,
	resync = false,
	jumps = 0, air_jumps = 0, stopped = 0, kept = 0, calls = 0, busy = 0, next_status = nil, next_menu_check = 0,
	last_change = nil, pending = false, retries = 0, settings = Settings.resolve({}, function() end) }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[DodgeJump] %s\n", ok and msg or tostring(fmt)))
end

local function warn(message)
	log("settings: %s", message)
end

local function load_settings()
	-- Read before the settings: a change saved in between has a higher number and comes again at the next look.
	local change = EVENTS_PATH and Menu.last_change(EVENTS_PATH)
	local s
	if SETTINGS_PATH == nil then
		s = Settings.resolve({}, warn)
	else
		s = Settings.load(SETTINGS_PATH, warn)
	end
	if s == nil then
		S.retries = S.retries + 1
		S.pending = S.retries <= MAX_READ_RETRIES
		if S.retries == 1 then
			warn("the settings file cannot be read now; trying again")
		elseif S.retries > MAX_READ_RETRIES then
			-- Without this, each menu event would start the reads again every second, without end.
			S.last_change = change
			if S.retries == MAX_READ_RETRIES + 1 then
				warn("the settings file still cannot be read; the settings stay as they are until the next loaded "
					.. "save or the next change in the Mods Menu")
			end
		end
		return
	end
	-- resync: buttons held as the settings change (the menu's confirm button, say) are not new presses.
	S.last_change, S.pending, S.retries, S.settings, S.resync = change, false, 0, s, true
	log("settings: %s", Settings.describe(s))
end

local function check_menu(now)
	if now < S.next_menu_check then return end
	S.next_menu_check = now + MENU_CHECK_EVERY
	if S.pending then
		load_settings()
		return
	end
	local change = EVENTS_PATH and Menu.last_change(EVENTS_PATH)
	if change ~= nil and (S.last_change == nil or change > S.last_change) then
		log("settings changed in the Mods Menu")
		load_settings()
	end
end

local function land(pawn, now)
	if S.in_air then
		S.jumps = S.jumps + 1
		if Air.landed(pawn, now, log) then S.stopped = S.stopped + 1 end
		Land.landed(now)
	end
	S.in_air = false
end

-- One line per jump would flood the log: counts and the mod's cost written every STATUS_EVERY seconds. No word a
-- mod manager takes for an error unless there is one: Phantom Blade Zero - Mod Manager (Nexus 2) paints red any
-- line with error(s), failed, failure, exception or fatal, and yellow warn(ing)(s); "0 errors" here had a player ask
-- what was wrong (5 November 2026). The errors are those since the last line, so one old error does not keep every
-- line red.
local function status(now)
	if S.next_status == nil then S.next_status = now + STATUS_EVERY end
	if now < S.next_status then return end
	S.next_status = now + STATUS_EVERY
	log("status: %d jumps or falls in the last %d minutes, %d air jumps, %d dodges stopped on landing, "
		.. "%d jumps pressed early and kept; %d calls (%.0f a second), %.1f microseconds a call on average%s",
		S.jumps, STATUS_EVERY // 60, S.air_jumps, S.stopped, S.kept, S.calls, S.calls / STATUS_EVERY,
		S.calls > 0 and S.busy / S.calls * 1e6 or 0,
		S.new_errors > 0 and string.format(", %d errors", S.new_errors) or "")
	S.jumps, S.air_jumps, S.stopped, S.kept, S.calls, S.busy, S.new_errors = 0, 0, 0, 0, 0, 0, 0
end

local function on_tick(controller)
	local now = os.clock()
	local pawn = nil
	pcall(function() pawn = controller.Pawn end)
	if not U.is_valid(pawn) then return end

	local addr = U.address(pawn)
	if addr ~= S.pawn or S.restarted then
		-- A loaded save or a respawn gives a new pawn, and the settings may have changed. ClientRestart says so even
		-- when the new pawn is made at the old one's address.
		S.pawn, S.cmc, S.in_air, S.retries, S.restarted = addr, nil, false, 0, false
		Objects.forget()
		Sound.forget()
		Land.reset(true)
		load_settings()
	end

	check_menu(now)
	local s = S.settings
	-- Switched off: only the pawn is looked at, for loaded saves. A jump under way just ends.
	if not s.enabled then
		S.in_air = false
		Land.reset()
		return
	end
	if not U.is_valid(S.cmc) then
		S.cmc = nil
		pcall(function() S.cmc = pawn.CharacterMovement end)
		if not U.is_valid(S.cmc) then return end
	end
	-- An unreadable mode is not a landing: the frame is skipped, the jump goes on.
	local mode = U.read(S.cmc, "MovementMode")
	if mode == nil then return end
	Keys.new_frame()
	local jump_keys = s.jump_keys
	if mode ~= FALLING then
		land(pawn, now)
		Land.ground(controller, jump_keys, now, log)
	else
		if not S.in_air then
			Air.takeoff(controller, s.air_keys)
			if Land.takeoff(controller, jump_keys) then S.kept = S.kept + 1 end
		end
		if S.resync then
			Air.hold(controller, s.air_keys)
			Land.hold(controller, jump_keys)
		end
		S.in_air = true
		local jumped = Air.update(controller, pawn, s.air_keys, s.chains * 2, s.speed,
			s.volume / Settings.MAX_VOLUME, now, log)
		S.air_jumps = S.air_jumps + jumped
		-- A press that made an air jump is not a jump to keep, when the two share a button.
		Land.air(controller, jump_keys, now, jumped > 0)
	end
	S.resync = false
end

local function safe_tick(self)
	local controller = U.unwrap(self)
	if controller == nil then return end
	local start = os.clock()
	local ok, err = pcall(on_tick, controller)
	S.calls, S.busy = S.calls + 1, S.busy + os.clock() - start
	if not ok then
		S.errors, S.new_errors = S.errors + 1, S.new_errors + 1
		if S.errors <= MAX_ERROR_LINES then
			log("error #%d: %s%s", S.errors, tostring(err),
				S.errors == MAX_ERROR_LINES and " (further errors are only counted in the status line)" or "")
		end
	end
	-- Outside on_tick: the status line is written even while an error repeats there.
	status(os.clock())
end

-- The player blueprints are not loaded when mods start; ClientRestart fires once the player has a pawn, then again
-- for each new pawn.
local function on_restart()
	S.restarted = true
	if S.hooked then return end
	local ok, err = pcall(function() RegisterHook(CONTROLLER_TICK, safe_tick) end)
	S.hooked = ok
	if ok then
		log("ready")
	else
		log("player controller not hookable yet (%s); retrying at the next pawn", tostring(err))
	end
end

log("Dodge Jump %s loaded", VERSION)
if SETTINGS_PATH ~= nil then Settings.ensure_file(SETTINGS_PATH, warn) end
-- Last: once it is set, ClientRestart can run the mod on the game thread while UE4SS's own thread is still in this
-- file, and two threads in one Lua state can corrupt it (crash audit, 4 November 2026).
local ok, err = pcall(function() RegisterHook(CLIENT_RESTART, on_restart) end)
if not ok then log("cannot watch for the player, the mod stays off (%s)", tostring(err)) end
