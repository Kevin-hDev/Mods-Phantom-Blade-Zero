-- Slide Anywhere for Phantom Blade Zero: a slide on one button, on the ground only, on flat ground, downhill and uphill
-- (Kevin, 4 November 2026). The game slides only inside volumes placed in its levels; starting its own slide anywhere
-- else freezes the character (SlideProbe, same day), so the mod plays the slide's animations and moves the character
-- itself (slide_run.lua), leaning it back so its feet stay on the ground (slide_tilt.lua).
-- The button the player picks, while running or just before a landing, slides (slide_trigger.lua); none is picked by
-- default, and with none the mod does nothing.
-- Settings (Enabled, the slide's buttons, SlideHold, its speed and length) in SlideAnywhere.config.json in the
-- mod's folder, changed in Mods Menu (Nexus 149) or by hand; read each time a save is loaded, and again within a
-- second of a change saved in the menu. Same settings and menu handling as Dodge Jump's main.lua.
--
-- The work happens in the player controller's ReceiveTick, hooked once the player has a pawn (ClientRestart). The hook
-- stays while the mod is off, against optimisation.md's rule 3.2: it is where the Mods Menu's changes are looked for,
-- and UE4SS runs the Lua of its timers and of native hooks outside the lock its blueprint hooks hold, where two threads
-- in one Lua state can crash the game (Dynamic FOV's dynamic_fov_driver.lua, crash audit of 4 November 2026).

local R = require("slide_reading")
local Slide = require("slide_run")
local Trigger = require("slide_trigger")
local Tilt = require("slide_tilt")
local Settings = require("slide_settings")
local Menu = require("slide_menu")
local Status = require("slide_status")
local Trial = require("slide_trial")
local Sound = require("slide_sound")

local VERSION = "1.0.0"
local CONTROLLER_TICK = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController."
	.. "BP_PlayerController_C:ReceiveTick"
local CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"
local SETTLE_SECONDS = 2.0
local MAX_DT = 0.1                -- a long frame (loading, hitch) counts for this much at most
-- The events (settings, a new pawn, what could not be done) have this many lines at most; the slides' detail, written
-- only by a trial build, has its own limit (slide_trial.lua).
local MAX_EVENT_LINES = 500
local MAX_ERROR_LINES = 5         -- a repeated error is written a few times, then only counted
local MENU_CHECK_EVERY = 1        -- seconds between two looks at the Mods Menu's event file
local MAX_READ_RETRIES = 5        -- looks spent on a settings file that exists but cannot be read
local MOD_DIR = Settings.mod_dir(debug.getinfo(1, "S").source)
local SETTINGS_PATH = MOD_DIR and Settings.file_in(MOD_DIR)
local EVENTS_PATH = MOD_DIR and Menu.events_file(MOD_DIR)

local S = { errors = 0, lines = 0, hooked = false, pawn_addr = nil, settle_until = nil, last = nil,
	restarted = false, off = false, resync = false, next_menu_check = 0, last_change = nil, reading = false,
	retries = 0, settings = Settings.resolve({}, function() end) }
-- This frame's pawn, and its state and floor normal once read (look).
local F = { pawn = nil, s = nil, normal = nil }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[SlideAnywhere] %s\n", ok and msg or tostring(fmt)))
end

local function say(fmt, ...)
	S.lines = S.lines + 1
	if S.lines <= MAX_EVENT_LINES then
		log(fmt, ...)
	elseif S.lines == MAX_EVENT_LINES + 1 then
		log("event limit reached (%d lines): further events are not written", MAX_EVENT_LINES)
	end
end

local function warn(message)
	say("settings: %s", message)
end

-- resync: buttons held as the settings change (the menu's confirm button, say) are not new presses.
local function apply(s)
	S.settings, S.resync = s, true
	Slide.configure(s)
	say("settings: %s", Settings.describe(s))
	if s.enabled and #s.keys == 0 then say("no slide button is set: pick one in Mods Menu, Slide Anywhere") end
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
		S.reading = S.retries <= MAX_READ_RETRIES
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
	S.last_change, S.reading, S.retries = change, false, 0
	apply(s)
end

local function check_menu(now)
	if now < S.next_menu_check then return end
	S.next_menu_check = now + MENU_CHECK_EVERY
	if S.reading then
		load_settings()
		return
	end
	local change = EVENTS_PATH and Menu.last_change(EVENTS_PATH)
	if change ~= nil and (S.last_change == nil or change > S.last_change) then
		say("settings changed in the Mods Menu")
		load_settings()
	end
end

-- The slide under way ends and the mesh gets its place back. why: a new pawn, the mod switched off, no button;
-- stop: the same pawn, whose slide animation is stopped too.
local function drop(why, stop)
	Slide.reset(say, why, stop)
	Tilt.reset(say)
	Trigger.reset()
end

local function look()
	if F.s == nil then
		F.s = R.state(F.pawn)
		F.normal = Slide.floor(F.s)
	end
	return F.s, F.normal
end

local function on_tick(controller)
	local now = os.clock()
	local dt = S.last and math.min(math.max(now - S.last, 0), MAX_DT) or 0
	S.last = now
	local pawn = nil
	pcall(function() pawn = controller.Pawn end)
	if not R.is_valid(pawn) then return end
	local addr = R.address(pawn)
	if addr ~= S.pawn_addr or S.restarted then
		-- A loaded save or a respawn gives a new pawn, and the settings may have changed. ClientRestart says so even
		-- when the new pawn is made at the old one's address.
		if S.pawn_addr ~= nil then say("player pawn changed (load or respawn), settling") end
		S.pawn_addr, S.settle_until, S.restarted, S.retries = addr, now + SETTLE_SECONDS, false, 0
		drop("the player pawn changed")
		Sound.forget()
		load_settings()
	end
	check_menu(now)
	-- Switched off, or no button: only the pawn and the menu are looked at. A slide under way ends at once, and back
	-- on the tilt looks for the mesh again (Tilt.reset forgets it).
	local s = S.settings
	if not s.enabled or #s.keys == 0 then
		if not S.off then
			S.off = true
			drop(s.enabled and "no slide button is set" or "the mod was switched off", true)
			S.settle_until = S.settle_until or now
		end
		return
	end
	S.off = false
	if S.settle_until ~= nil then
		if now < S.settle_until then return end
		-- apply() resyncs too, but not after a load that could not read the settings file.
		S.settle_until, S.resync = nil, true
		say("pawn ready: %s", R.class_name(pawn))
		Tilt.on_pawn(say, pawn)
	end
	if S.resync then
		S.resync = false
		Trigger.reset(controller, s.keys)
	end
	F.pawn, F.s, F.normal = pawn, nil, nil
	if Trigger.frame(say, controller, pawn, s, now, look) then Status.slide() end
	Slide.frame(say, now, dt, pawn, look)
	Tilt.frame(say, dt, look)
end

local function safe_tick(self)
	local controller = R.unwrap(self)
	if controller == nil then return end
	local start = os.clock()
	local ok, err = pcall(on_tick, controller)
	-- The lean easing back after a slide costs about as much as a slide's frame (audit of 0.5.2): counted with them.
	Status.tick(os.clock() - start, Slide.running() or Tilt.busy(), not ok)
	if not ok then
		S.errors = S.errors + 1
		if S.errors <= MAX_ERROR_LINES then
			log("tick error #%d: %s%s", S.errors, tostring(err),
				S.errors == MAX_ERROR_LINES and " (further errors are only counted in the status line)" or "")
		end
	end
	-- Outside on_tick: the status line is written even while an error repeats there.
	Status.write(os.clock(), log)
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

log("Slide Anywhere %s loaded", VERSION)
Trial.start(log)
if SETTINGS_PATH ~= nil then Settings.ensure_file(SETTINGS_PATH, warn) end
-- Last: once it is set, ClientRestart can run the mod on the game thread while UE4SS's own thread is still in this
-- file, and two threads in one Lua state can corrupt it (crash audit of 4 November 2026).
local ok, err = pcall(function() RegisterHook(CLIENT_RESTART, on_restart) end)
if not ok then log("cannot watch for the player, the mod stays off (%s)", tostring(err)) end
