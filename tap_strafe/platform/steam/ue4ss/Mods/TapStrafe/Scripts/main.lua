-- Tap Strafe for Phantom Blade Zero: in the air, the jump's momentum turns as the camera turns (mouse or right stick),
-- even without touching the movement keys. Off while an enemy is locked. One setting, the Enabled switch, in
-- TapStrafe.config.json in the mod's folder, changed in Mods Menu (Nexus 149) or by hand; read each time a save is
-- loaded, and again within a second of a change saved in the menu.
--
-- The work happens in the player controller's ReceiveTick, before the movement component: TapProbe (3 November 2026)
-- showed the character travels along the velocity written there, within 2 degrees over 23 jumps.
-- Settings and menu handling follow Jump Strafe's main.lua.

local U = require("tap_strafe_unreal")
local Settings = require("tap_strafe_settings")
local Menu = require("tap_strafe_menu")
local Turn = require("tap_strafe_turn")

local VERSION = "1.0.0"
local CONTROLLER_TICK = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController.BP_PlayerController_C:ReceiveTick"
local CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"
local FALLING = 3                 -- EMovementMode::MOVE_Falling: jumps and falls
local STATUS_EVERY = 600          -- seconds between two status lines, only after jumps
local MENU_CHECK_EVERY = 1        -- seconds between two looks at the Mods Menu's event file
local MAX_READ_RETRIES = 5        -- looks spent on a settings file that exists but cannot be read
local MOD_DIR = Settings.mod_dir(debug.getinfo(1, "S").source)
local SETTINGS_PATH = MOD_DIR and Settings.file_in(MOD_DIR)
local EVENTS_PATH = MOD_DIR and Menu.events_file(MOD_DIR)

local S = { hooked = false, errors = 0, pawn = nil, in_air = false, jump = nil,
	jumps = 0, turned = 0, locked = 0, next_status = nil, next_menu_check = 0, last_change = nil, pending = false,
	retries = 0, enabled = true }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[TapStrafe] %s\n", ok and msg or tostring(fmt)))
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
	S.last_change, S.pending, S.retries, S.enabled = change, false, 0, s.enabled
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

-- One line per jump would flood the log: counts per jump, written every STATUS_EVERY seconds.
local function land()
	if S.in_air and S.jump ~= nil then
		S.jumps = S.jumps + 1
		if S.jump.turned then S.turned = S.turned + 1 end
		if S.jump.locked then S.locked = S.locked + 1 end
	end
	S.in_air, S.jump = false, nil
end

local function status(now)
	if S.next_status == nil then S.next_status = now + STATUS_EVERY end
	if now < S.next_status then return end
	S.next_status = now + STATUS_EVERY
	if S.jumps > 0 then
		log("status: %d jumps or falls in the last %d minutes, turned in %d, locked in %d", S.jumps, STATUS_EVERY // 60,
			S.turned, S.locked)
	end
	S.jumps, S.turned, S.locked = 0, 0, 0
end

local function on_tick(controller)
	local now = os.clock()
	local pawn = nil
	pcall(function() pawn = controller.Pawn end)
	if not U.is_valid(pawn) then return end

	local addr = U.address(pawn)
	if addr ~= S.pawn then
		-- A loaded save or a respawn gives a new pawn, and the settings may have changed.
		S.pawn, S.in_air, S.jump, S.retries = addr, false, nil, 0
		Turn.forget()
		load_settings()
	end

	check_menu(now)                   -- before the turn, so a change from the menu applies this frame
	-- Switched off: treated as on the ground, so a jump under way ends here, and nothing more of the game is read.
	if not S.enabled then
		land()
		status(now)
		return
	end
	local cmc = nil
	pcall(function() cmc = pawn.CharacterMovement end)
	if not U.is_valid(cmc) then return end
	if U.read(cmc, "MovementMode") ~= FALLING then
		land()
	else
		if not S.in_air then
			S.jump = { turned = false, locked = false }
			Turn.new_jump()
		end
		S.in_air = true
		local what = Turn.update(controller, pawn, cmc, log)
		if what == "turned" then S.jump.turned = true elseif what == "locked" then S.jump.locked = true end
	end
	status(now)
end

local function safe_tick(self)
	local controller = U.unwrap(self)
	if controller == nil then return end
	local ok, err = pcall(on_tick, controller)
	if not ok then
		S.errors = S.errors + 1
		if S.errors <= 5 or S.errors % 1000 == 0 then log("error #%d: %s", S.errors, tostring(err)) end
	end
end

-- The player blueprints are not loaded when mods start; ClientRestart fires once the player has a pawn.
local function try_hook()
	if S.hooked then return end
	local ok, err = pcall(function() RegisterHook(CONTROLLER_TICK, safe_tick) end)
	S.hooked = ok
	if ok then
		log("ready, turning on")
	else
		log("player controller not hookable yet (%s); retrying at the next pawn", tostring(err))
	end
end

local ok, err = pcall(function() RegisterHook(CLIENT_RESTART, try_hook) end)
log("Tap Strafe %s loaded%s", VERSION,
	ok and "" or (": cannot watch for the player, the mod stays off (" .. tostring(err) .. ")"))
if SETTINGS_PATH ~= nil then Settings.ensure_file(SETTINGS_PATH, warn) end
