-- Jump Strafe for Phantom Blade Zero: steer your jumps and falls with the movement keys or the left stick.
-- Settings: JumpStrafe.config.json in the mod's folder, changed in Mods Menu (Nexus 149) or by hand. They are read
-- each time a save is loaded, and again within a second of a change saved in the menu.
--
-- The work happens in the player controller's ReceiveTick, which runs after input and before the movement
-- component: what is written there is what this frame's movement uses (our probe, 3 November 2026).

local U = require("jump_strafe_unreal")
local Settings = require("jump_strafe_settings")
local Menu = require("jump_strafe_menu")
local Air = require("jump_strafe_air")

local VERSION = "1.0.0"
local CONTROLLER_TICK = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController.BP_PlayerController_C:ReceiveTick"
local CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"
local FALLING = 3                 -- EMovementMode::MOVE_Falling: jumps and falls
local STATUS_EVERY = 600          -- seconds between two status lines, only when something was steered
local MENU_CHECK_EVERY = 1        -- seconds between two looks at the Mods Menu's event file
local MAX_READ_RETRIES = 5        -- looks spent on a settings file that exists but cannot be read
local MOD_DIR = Settings.mod_dir(debug.getinfo(1, "S").source)
local SETTINGS_PATH = MOD_DIR and Settings.file_in(MOD_DIR)
local EVENTS_PATH = MOD_DIR and Menu.events_file(MOD_DIR)

local S = { hooked = false, errors = 0, pawn = nil, in_air = false, jumps = 0, next_status = nil,
	next_menu_check = 0, last_change = nil, pending = false, retries = 0, enabled = true }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[JumpStrafe] %s\n", ok and msg or tostring(fmt)))
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
		elseif S.retries == MAX_READ_RETRIES + 1 then
			warn("the settings file still cannot be read; the settings stay as they are until the next loaded save")
		end
		return
	end
	S.last_change, S.pending, S.retries, S.enabled = change, false, 0, s.enabled
	Air.configure(s)
	log("settings: grip %s (air acceleration %d), keep momentum %s, mod %s", s.grip, s.air_accel,
		s.keep_momentum and "on" or "off", s.enabled and "on" or "off")
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

local function status(now)
	if S.next_status == nil then S.next_status = now + STATUS_EVERY end
	if now < S.next_status then return end
	S.next_status = now + STATUS_EVERY
	if S.jumps > 0 then log("status: %d jumps or falls steered in the last %d minutes", S.jumps, STATUS_EVERY // 60) end
	S.jumps = 0
end

local function on_tick(controller)
	local pawn, cmc = nil, nil
	pcall(function() pawn = controller.Pawn end)
	if not U.is_valid(pawn) then return end
	pcall(function() cmc = pawn.CharacterMovement end)
	if not U.is_valid(cmc) then return end

	local addr = U.address(pawn)
	if addr ~= S.pawn then
		-- A loaded save or a respawn gives a new pawn: nothing of ours is on it, and the settings may have changed.
		S.pawn, S.in_air, S.retries = addr, false, 0
		Air.forget()
		load_settings()
	end

	local now = os.clock()
	check_menu(now)                   -- before the air values, so a change from the menu applies this frame
	-- Switched off: treated as on the ground, so values of ours still on the character are given back at once.
	local falling = S.enabled and U.read(cmc, "MovementMode") == FALLING
	if falling and not S.in_air then S.jumps = S.jumps + 1 end
	S.in_air = Air.update(cmc, falling)
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
		log("ready, steering on")
	else
		log("player controller not hookable yet (%s); retrying at the next pawn", tostring(err))
	end
end

local ok, err = pcall(function() RegisterHook(CLIENT_RESTART, try_hook) end)
log("Jump Strafe %s loaded%s", VERSION, ok and "" or (": cannot watch for the player, the mod stays off (" .. tostring(err) .. ")"))
if SETTINGS_PATH ~= nil then Settings.ensure_file(SETTINGS_PATH, warn) end
