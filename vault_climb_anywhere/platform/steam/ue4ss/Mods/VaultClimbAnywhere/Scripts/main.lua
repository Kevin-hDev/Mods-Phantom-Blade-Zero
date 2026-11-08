-- Vault & Climb Anywhere for Phantom Blade Zero: the jump pressed before an obstacle the game will not traverse vaults
-- over it or climbs onto it, up to 5 m, with the game's own animations. The game's motion reactor component vaults
-- only over obstacles 75 to 155 cm high: the mod widens its setup (vault_setup.lua) and, when the game still refuses,
-- reads the obstacle itself and hands the game its plan (vault_jump.lua). The jump is the game's own, on the keys set
-- in its options (vault_jump_keys.lua).
-- Settings in VaultClimbAnywhere.config.json in the mod's folder, changed in Mods Menu or by hand; read each time a
-- save is loaded, and again within a second of a change saved in the menu (vault_settings_watch.lua).
--
-- The work happens in the player controller's ReceiveTick, hooked once the player has a pawn (ClientRestart). The hook
-- stays while the mod is off: it is where the menu's changes are looked for, and UE4SS runs the Lua of its timers and
-- of native hooks outside the lock its blueprint hooks hold, where two threads in one Lua state can crash the game.
-- It never loads anything; it searches by path, once each, only the two function libraries it calls and the three
-- classes it checks objects against (vault_classes.lua), which always exist.
-- At rest the component is read once a second, and on each frame only while a press, a jump followed or our traversal
-- needs it. The game's pause stops what the mod follows (vault_pause.lua). Switched off, the mod puts the game's setup
-- back, and its safety net still watches our traversal to its end.

local R = require("vault_reading")
local Settings = require("vault_settings")
local Config = require("vault_settings_watch")
local Menu = require("vault_menu")
local Classes = require("vault_classes")
local Setup = require("vault_setup")
local Jump = require("vault_jump")
local JumpKeys = require("vault_jump_keys")
local Perform = require("vault_perform")
local Pause = require("vault_pause")
local Keys = require("vault_keys")
local Watch = require("vault_watch")
local Status = require("vault_status")
local Trial = require("vault_trial")

local VERSION = "1.0.0"
local CONTROLLER_TICK = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController."
	.. "BP_PlayerController_C:ReceiveTick"
local CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"
local REACTOR = "/Script/ProjectPBZ.SMotionReactorComponent"
local SETTLE_SECONDS = 2.0        -- s after a new pawn (a loaded save, a respawn) before the mod acts
local COMP_EVERY = 1              -- s between two reads of the component at rest
local MAX_EVENT_LINES = 500
local MAX_ERROR_LINES = 5         -- a repeated error is written a few times, then only counted
local MOD_DIR = Settings.mod_dir(debug.getinfo(1, "S").source)
local SETTINGS_PATH = MOD_DIR and Settings.file_in(MOD_DIR)
local EVENTS_PATH = MOD_DIR and Menu.events_file(MOD_DIR)

-- resync: the jump's keys held now are not new presses (a character ready). comp: the address of the component set up
-- now, nil while off; held: the one set up last on this pawn, to tell the mod switched back on from a new character;
-- refresh: the settings changed since it was set up; missing: a pawn without the component was said; next_comp: when
-- to read the component again at rest.
local S = { errors = 0, lines = 0, hooked = false, pawn_addr = nil, settle_until = nil, restarted = false,
	off = false, resync = false, refresh = false, comp = nil, held = nil, missing = false, next_comp = 0 }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[VaultClimbAnywhere] %s\n", ok and msg or tostring(fmt)))
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

-- The player's motion reactor component, or nil.
local function reactor(pawn)
	local comp = R.field(pawn, "BP_MotionReactorComponent")
	if R.usable(comp, Classes.get(REACTOR)) then
		S.missing = false
		return comp
	end
	if not S.missing then
		S.missing = true
		say("no motion reactor component on %s: nothing to do for this character", R.class_name(pawn))
	end
	return nil
end

-- The press under way is let go (why, for its line), our traversal forgotten unless on the same pawn, and the game's
-- setup put back on comp when it still holds the mod's.
local function drop(comp, why, same_pawn)
	Jump.reset(why)
	if not same_pawn then Perform.reset() end
	Watch.reset()
	if comp ~= nil then Setup.restore(say, comp) end
	S.comp = nil
end

-- The component set up when it is new to the mod (a new character, the mod switched on), with the settings when they
-- changed, else kept against the game's own changes.
local function set_up(comp, now)
	local addr = R.address(comp)
	if addr ~= S.comp then
		local again = addr == S.held
		if not again and Trial.open() then Trial.say("%s", Setup.describe(comp)) end
		Setup.start(say, comp, now, again and "mod switched on" or "new character")
		S.comp, S.held, S.refresh = addr, addr, false
	elseif S.refresh then
		S.refresh = false
		Setup.refresh(say, comp, now)
	else
		Setup.keep(say, comp, now)
	end
end

-- Switched off: the safety net watches our traversal started before, on its paused clock, until it ends.
local function net(controller, pawn, now)
	if Pause.check(say, controller, now) then return end
	local comp = reactor(pawn)
	if comp == nil then return Perform.reset() end
	Perform.keep(say, nil, comp, pawn, R.field(comp, "DoingTraversalAction"), Pause.clock(now))
end

-- The pawn ready: its keys read at once, and in a trial build its capsule, which places a hurdle's landing.
local function ready(pawn)
	S.settle_until, S.resync, S.next_comp = nil, true, 0
	JumpKeys.reset()
	say("pawn ready: %s", R.class_name(pawn))
	if Trial.open() then
		Trial.say("the character's capsule: radius %s cm, half height %s cm",
			R.text(R.read(function() return pawn.CapsuleComponent:GetScaledCapsuleRadius() end)),
			R.text(R.read(function() return pawn.CapsuleComponent:GetScaledCapsuleHalfHeight() end)))
	end
end

-- The jump's keys this frame: whether one was pressed, the game's pause looked at on that frame and while something
-- is followed. nil when the game is paused while something is followed: then nothing goes on. The keys are read on
-- each frame of a pause too, so that a key held past it is not a press.
local function press(controller, pawn, now, busy)
	local keys = JumpKeys.keys()
	if JumpKeys.frame(say, controller, now) or S.resync then
		S.resync, keys = false, JumpKeys.keys()
		Jump.resync(controller, keys)
	end
	local pressed = Jump.pressed(controller, keys)
	if not (busy or pressed) then return false end
	local paused = Pause.check(say, controller, now)
	if paused and pressed then Jump.paused_press(pawn) end
	if paused and busy then return nil end
	return pressed and not paused
end

local function on_tick(controller)
	local now = os.clock()
	local pawn = R.field(controller, "Pawn")
	if not R.is_valid(pawn) then return end
	local addr = R.address(pawn)
	if addr ~= S.pawn_addr or S.restarted then
		-- A loaded save or a respawn gives a new pawn, and the settings may have changed. ClientRestart says so even
		-- when the new pawn is made at the old one's address, which may still hold the mod's setup while it is off.
		if S.pawn_addr ~= nil then say("player pawn changed (load or respawn), settling") end
		S.pawn_addr, S.settle_until, S.restarted, S.held = addr, now + SETTLE_SECONDS, false, nil
		drop(S.off and reactor(pawn) or nil, "the player pawn changed")
		Config.new_pawn()
	end
	Config.check(now)
	if not Config.loaded() then return end
	if Config.take_changed() then S.refresh = true end
	-- Switched off: the game's setup back once, then only the pawn, the menu and our traversal's end are looked at.
	if not Settings.current.enabled then
		if not S.off then
			S.off = true
			drop(reactor(pawn), "the mod was switched off", true)
			S.settle_until = S.settle_until or now
		end
		if Perform.running() then net(controller, pawn, now) end
		return
	end
	S.off = false
	if S.settle_until ~= nil then
		if now < S.settle_until then return end
		ready(pawn)
	end
	Keys.new_frame(controller)
	local busy = Jump.busy() or Perform.running()
	local pressed = press(controller, pawn, now, busy)
	if pressed == nil then return end
	local detail = Trial.open()
	-- New settings reach the game at once, not up to a second after the menu's change is read.
	local need = pressed or busy or S.refresh or now >= S.next_comp
	if not (need or detail) then return end
	-- A trial build reads the component and the traversal on each frame for its watch: that time is its detail.
	local start = os.clock()
	local comp = reactor(pawn)
	if comp == nil then return end
	if need then
		S.next_comp = now + COMP_EVERY
		set_up(comp, now)
		start = os.clock()
	end
	-- Read only while something uses it: a press, a jump followed, our traversal, a trial build's watch. Before the
	-- jump: doing is read before the traversal of ours the jump may start in this frame, which would then read as
	-- already ended.
	local doing = nil
	if detail or busy or pressed then doing = R.field(comp, "DoingTraversalAction") end
	if not (busy or pressed) then Status.detail(os.clock() - start) end
	local clock = Pause.clock(now)
	Perform.keep(say, detail and Trial.say or nil, comp, pawn, doing, clock)
	if detail or busy or pressed then Jump.frame(say, comp, pawn, doing, clock, pressed) end
	if detail then Watch.frame(controller, comp, pawn, doing) end
end

local function safe_tick(self)
	local controller = R.unwrap(self)
	if controller == nil then return end
	local start = os.clock()
	local ok, err = pcall(on_tick, controller)
	Status.tick(os.clock() - start, Jump.busy() or Perform.running(), not ok)
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

log("Vault & Climb Anywhere %s loaded%s", VERSION, Trial.on and " (trial build: each jump is written in detail)" or "")
Trial.start(log)
Keys.start(say)
Config.start(say, SETTINGS_PATH, EVENTS_PATH)
if SETTINGS_PATH ~= nil then Settings.ensure_file(SETTINGS_PATH, warn) end
-- Last: once it is set, ClientRestart can run the mod on the game thread while UE4SS's own thread is still in this
-- file, and two threads in one Lua state can corrupt it.
local ok, err = pcall(function() RegisterHook(CLIENT_RESTART, on_restart) end)
if not ok then log("cannot watch for the player, the mod stays off (%s)", tostring(err)) end
