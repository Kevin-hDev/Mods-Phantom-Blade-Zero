-- Movement Tuning for Phantom Blade Zero: faster walking, running, sprinting, moves (dodges, jump recovery, wall runs,
-- ladders, ropes and slides, weapon draw, stance) and attacks, each at its own speed or all at the Global one, higher
-- jumps, a left stick curve that lets the player walk, the sticks' dead zones, auto or toggle sprint (which give way
-- to the game's walk), the sprint or only the high-speed sprint turned off or its wait changed, stops without a slide
-- when sped up, full speed again at the end of a special move or of a dodge, whose landing goes faster, and Realism
-- (movement_realism.lua). Settings in MovementTuning.config.json in the mod's folder, changed in Mods Menu (Nexus 149)
-- or by hand (movement_watch.lua).
--
-- The work happens in the player controller's ReceiveTick.

local U = require("movement_unreal")
local Family = require("movement_family")
local File = require("movement_file")
local Watch = require("movement_watch")
local Tasks = require("movement_tasks")
local Speed = require("movement_speed")
local Timeline = require("movement_timeline")
local Ground = require("movement_ground")
local Jump = require("movement_jump")
local Stick = require("movement_stick")
local Sprints = require("movement_sprints")
local Tags = require("movement_tags")
local Resume = require("movement_resume")
local Dodge = require("movement_dodge")
local Press = require("movement_press")
local SprintOff = require("movement_sprint_off")
local Brake = require("movement_brake")
local Realism = require("movement_realism")

local VERSION = "1.0.4"
local CONTROLLER_TICK = "/Game/PBZContent/Blueprint/Character/Player/BP_PlayerController.BP_PlayerController_C:ReceiveTick"
local CLIENT_RESTART = "/Script/Engine.PlayerController:ClientRestart"
local STATUS_EVERY = 600          -- seconds between two status lines
local MAX_ERROR_LINES = 5         -- a repeated error is written a few times, then only counted
local SLOW_CALL = 0.002           -- seconds: a call surely longer is counted in the status line
local CLOCK_STEP = 0.001          -- os.clock moves by whole milliseconds on Windows (every longest call in the status
                                  -- lines is one): a call read at 2 ms took 1 to 3, one read at 3 or more took over 2
local SCRIPT_SOURCE = debug.getinfo(1, "S").source
local MOD_DIR = File.mod_dir(SCRIPT_SOURCE)

-- errors: since the start, for the error lines; window_errors: since the last status line. longest, slow: the longest
-- call and the calls over SLOW_CALL since the last status line.
-- asc, asc_addr: the pawn's ability system and its address, kept while it stays valid.
local S = { hooked = false, restarted = false, errors = 0, window_errors = 0, pawn = nil, calls = 0, busy = 0,
	tasks = 0, pushes = {}, longest = 0, slow = 0, next_status = nil, asc = nil, asc_addr = nil }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[MovementTuning] %s\n", ok and msg or tostring(fmt)))
end

-- One line per move would flood the log: counts and the mod's cost written every STATUS_EVERY seconds. No word a mod
-- manager takes for an error unless there is one: mod managers paint red any line with error(s), failed, failure,
-- exception or fatal, and yellow warn(ing)(s), even "0 errors". The errors are those since the last line.
local function status(now)
	if S.next_status == nil then S.next_status = now + STATUS_EVERY end
	if now < S.next_status then return end
	S.next_status = now + STATUS_EVERY
	S.window_errors = S.window_errors + Tasks.errors()
	local parts = {}
	for key, n in pairs(S.pushes) do parts[#parts + 1] = string.format("%s %d", key, n) end
	table.sort(parts)
	local moving = Ground.report() .. "; " .. Sprints.report() .. "; " .. Resume.report() .. "; " .. SprintOff.report()
	log("status: in the last %d minutes, frames sped up: %s; %s; %d calls (%.0f a second), %d tasks looked at, "
		.. "%d known, %d timelines unreadable, %.1f microseconds a call on average, longest %.0f ms (1 ms clock), %d "
		.. "over %.0f ms%s",
		STATUS_EVERY // 60,
		#parts > 0 and table.concat(parts, ", ") or "none", moving, S.calls, S.calls / STATUS_EVERY,
		S.tasks, Speed.remembered(), Timeline.report(),
		S.calls > 0 and S.busy / S.calls * 1e6 or 0, S.longest * 1e3, S.slow, SLOW_CALL * 1e3,
		S.window_errors > 0 and string.format(", %d errors", S.window_errors) or "")
	S.calls, S.busy, S.tasks, S.pushes, S.window_errors, S.longest, S.slow = 0, 0, 0, {}, 0, 0, 0
end

-- A loaded save or a respawn gives a new pawn, and the settings may have changed. ClientRestart says so even when the
-- new pawn is made at the old one's address, and for the same pawn taken back (the end of a cutscene): a raised jump
-- then ends with the game's gravity, and the gravities the mod wrote stay known.
local function new_pawn(pawn, addr, now)
	if addr == S.pawn then
		Jump.restart((U.movement(pawn)), now, log)
		Stick.restart()
	else
		Jump.forget()
		Stick.forget()
	end
	Sprints.forget()
	Tags.forget()
	Resume.forget()
	Press.forget()
	Brake.forget()
	Realism.forget()
	S.pawn, S.restarted, S.asc, S.asc_addr = addr, false, nil, nil
	Speed.forget()
	-- A load can unload a class or a timeline and put another at its address: both are read anew, one at a time.
	Family.forget()
	Timeline.forget()
	Ground.forget()
	Watch.reload()
end

-- hooked: the hook's parameter, unwrapped only once the mod has work to do (a call to the game).
local function on_tick(hooked)
	local now = os.clock()
	local s = Watch.settings()
	local busy = s.enabled and (s.resume or s.landing or s.high_off or s.high_delay ~= nil or s.realistic
		or not (s.ground_neutral and s.jump_neutral and s.timeline_neutral and s.stick_neutral))
	-- Off, or every setting at the game's own, with nothing of the mod's left on the character: nothing is read from
	-- the game, not even the pawn. A new pawn still reads the settings: ClientRestart sets restarted.
	if not busy and not S.restarted and not Ground.holding() and not Jump.holding(now) and not Stick.holding()
		and not SprintOff.holding() and not Brake.holding() and not Realism.holding() then
		Watch.check(now)
		return
	end
	local controller = U.unwrap(hooked)
	if controller == nil then return end
	local pawn = nil
	pcall(function() pawn = controller.Pawn end)
	if not U.is_valid(pawn) then return end
	local addr = U.address(pawn)
	if addr ~= S.pawn or S.restarted then new_pawn(pawn, addr, now) end
	Watch.check(now)
	s = Watch.settings()

	local stick_on = s.enabled and not s.stick_neutral
	local left = stick_on and s.stick.left or nil
	local push, travel = nil, nil
	if stick_on or Stick.holding() then
		push, travel = Stick.frame(controller, pawn, now, stick_on and s.stick or nil, log)
	end
	local resume_on = s.enabled and s.resume
	local landing_on = s.enabled and s.landing
	local realistic = s.enabled and s.realistic
	-- The resume needs the game's speeds, and its long sprint's hold is written by the ground speeds, whose drops
	-- Realism eases.
	local ground_on = s.enabled and (not s.ground_neutral or left ~= nil or resume_on or realistic)
	local jump_on = s.enabled and not s.jump_neutral
	local cmc, mode = nil, nil
	if ground_on or jump_on or landing_on or Ground.holding() or Jump.holding(now) or Realism.holding() then
		cmc, mode = U.movement(pawn)
	end
	local real = Realism.frame(pawn, cmc, mode, realistic and s.realism or nil, realistic and s.hyper, now, log)
	Sprints.frame(controller, pawn, s, stick_on, travel, now, log)
	if ground_on then
		-- The long sprint held by the resume, never while it is turned off (chosen during one, it would come back).
		local floor = resume_on and Resume.floor(now) or nil
		Ground.frame(pawn, cmc, mode, now, s.rates, log, push, left, not (s.enabled and s.high_off) and floor or nil,
			real)
		Brake.frame(cmc, mode, Ground.factor_now(), push, now, log)
	else
		Ground.release(cmc)
		Brake.release(cmc)
	end
	-- The dodge's watch, run by the resume (movement_resume.lua), serves both the resume and the faster landing.
	if resume_on or landing_on then
		Resume.frame(pawn, cmc, mode, now, Ground.game_speed(), Ground.gaits(), s.rates, resume_on, landing_on, log)
	else
		Resume.stop()
	end
	if jump_on then
		Jump.frame(pawn, cmc, mode, now, s.jump_height, log, Speed.seen_at("jump"))
	else
		Jump.pause(cmc, now, log)
	end
	if not s.enabled then return end
	-- While a dodge plays on the ground with the faster landing on, the timelines are looked at even with every move at
	-- the game's pace: its landing goes faster (movement_landing.lua).
	local dodging = Dodge.rates(s.rates)
	if s.timeline_neutral and dodging == nil then return end
	if not U.is_valid(S.asc) then
		local asc = nil
		pcall(function() asc = pawn.AbilitySystemComponent end)
		S.asc = U.is_valid(asc) and asc or nil
		S.asc_addr = S.asc and U.address(S.asc)
	end
	if S.asc_addr == nil then return end
	S.tasks = S.tasks + Speed.frame(S.asc_addr, now, dodging or s.rates, S.pushes, log)
	if Timeline.first_unreadable() then
		log("the actions of a timeline cannot be read: that timeline keeps the game's pace")
	end
end

local function safe_tick(self)
	local start = os.clock()
	local ok, err = pcall(on_tick, self)
	local took = os.clock() - start
	S.calls, S.busy = S.calls + 1, S.busy + took
	if took > S.longest then S.longest = took end
	if took > SLOW_CALL + CLOCK_STEP / 2 then S.slow = S.slow + 1 end
	if not ok then
		S.errors, S.window_errors = S.errors + 1, S.window_errors + 1
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

log("Movement Tuning %s loaded", VERSION)
if MOD_DIR == nil then
	log("the mod's folder cannot be found from %s: the settings stay at their defaults", tostring(SCRIPT_SOURCE))
end
Watch.init(MOD_DIR, log)
-- Set at the end too, as ClientRestart below: the game calls it on its own thread, and makes no ability task before
-- the player has a pawn.
local watched, why = Tasks.watch(log)
if not watched then
	log("cannot watch the game's moves (%s): moves and attacks keep the game's pace", tostring(why))
end
-- Last: once it is set, ClientRestart can run the mod on the game thread while UE4SS's own thread is still in this
-- file, and two threads in one Lua state can corrupt it.
local ok, err = pcall(function() RegisterHook(CLIENT_RESTART, on_restart) end)
if not ok then log("cannot watch for the player, the mod stays off (%s)", tostring(err)) end
