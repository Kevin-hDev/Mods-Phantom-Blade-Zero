-- One slide, from the button picked in the settings (slide_trigger.lua) to its end: the slope slide's start, its loop
-- played again until the slide ends, then a fade into the game's running. Every slide leans the character back
-- (slide_tilt.lua). Pressing the button again ends it, once it has shown for MIN_TIME; with SlideHold, holding the
-- button keeps its speed and letting it go after HOLD_TIME ends it (slide_motion.lua). A rock, a wall or a fence that
-- slows it takes that speed away; taking more than half, it ends the slide (slide_blocked.lua).
-- The speed comes from slide_motion.lua, with the speed and length settings taken at the slide's start, and is written
-- into the character's velocity every frame; the character faces
-- the slide and the stick turns it; the game's own steering is held (slide_control.lua). The animation's own motion is
-- ignored: alone, the slope slide moved the character 24 m in 2.9 s on flat ground (first trial).
-- Ground only: leaving the ground stops the slide at once; another animation (attack, dodge) ends it too.
-- The game's ground slide sounds play with it (slide_sound.lua).
-- A trial build writes each slide's start and end and, every LOG_EVERY s, the speed wanted, kept in the game's
-- velocity and really moved, slope, movement mode, the montage playing, the lean (slide_trial.lua).

local R = require("slide_reading")
local Trial = require("slide_trial")
local Blocked = require("slide_blocked")
local Anim = require("slide_anim")
local Sets = require("slide_sets")
local Motion = require("slide_motion")
local Control = require("slide_control")
local Tilt = require("slide_tilt")
local Sound = require("slide_sound")

local M = {}

local WALKING = 1                 -- EMovementMode
local LOG_EVERY = 0.1
local STEER_RATE = 120            -- degrees per second toward the stick
local MIN_INPUT = 0.3             -- a stick barely pushed is not a direction
local MOVING = 50                 -- below this speed, the slide goes where the character faces
local RUNNING = 400               -- a button slides only above this speed (walk 130, jog 600)
local f = R.f

-- holding: with SlideHold, a button held this frame (M.hold).
local S = { slide = nil, n = 0, holding = false }
-- The settings the next slide takes (M.configure): speed and length, 1 to 3.
local C = { speed = 1, length = 1 }

-- cmc: the movement component read this frame (slide_reading.lua's state).
local function floor_normal(cmc)
	local n = nil
	pcall(function() n = R.vec(cmc.CurrentFloor.HitResult.ImpactNormal) end)
	return n
end

local function floor_angle(n, yaw)
	local r = math.rad(yaw)
	return Motion.slope(n, math.cos(r), math.sin(r))
end

-- Turns the slide's yaw toward the stick's direction, at most STEER_RATE x dt.
local function steer(pawn, yaw, dt)
	local v = nil
	pcall(function() v = R.vec(pawn:GetLastMovementInputVector()) end)
	if v == nil or v.x * v.x + v.y * v.y < MIN_INPUT * MIN_INPUT then return yaw end
	local gap = (math.deg(math.atan(v.y, v.x)) - yaw + 180) % 360 - 180
	local most = STEER_RATE * dt
	return yaw + math.max(-most, math.min(most, gap))
end

local function push(pawn, s, w)
	local r = math.rad(w.yaw)
	local ok = pcall(function()
		s.cmc.Velocity = { X = math.cos(r) * w.push, Y = math.sin(r) * w.push, Z = s.vz or 0 }
	end)
	if not ok then w.push_failed = w.push_failed + 1 end
	pcall(function() pawn:K2_SetActorRotation({ Pitch = 0, Yaw = w.yaw, Roll = 0 }, false) end)
end

-- Returns false when the animation did not play.
local function enter(w, now, phase)
	local length = Anim.play(w.anim, w.objs[phase], Sets.SLIDE[phase])
	w.phase, w.phase_end = phase, now + (length or 0)
	if phase == "loop" then w.loops = w.loops + 1 end
	return length ~= nil
end

local function finish(say, now, s, why, stop)
	local w = S.slide
	S.slide = nil
	if stop then Anim.stop(w.anim) else Anim.forget() end
	Anim.restore_root_motion(say)
	local rewritten = Control.release(say)
	Sound.stop(say, stop and s.mode == WALKING)
	if Trial.open() then
		local flat, dz = nil, nil
		if w.pos0 ~= nil and s.pos ~= nil then
			local dx, dy = s.pos.x - w.pos0.x, s.pos.y - w.pos0.y
			flat, dz = math.sqrt(dx * dx + dy * dy), s.pos.z - w.pos0.z
		end
		Trial.say("slide #%d end: %s after %.2f s, travel=%s dz=%s top speed=%s end speed=%s slope %s..%s loops=%d "
			.. "steering rewritten=%d push failures=%d slowed=%d held=%.2f s", w.n, why, now - w.t0, f(flat), f(dz),
			f(w.top), f(w.push), f(w.low, "%.1f"), f(w.high, "%.1f"), w.loops, rewritten, w.push_failed, w.slowed,
			w.held)
	end
	Tilt.finish(say)
end

-- why: what started it, the button's name; speed: the speed the slide starts from. Returns true when the slide started.
local function press(say, now, pawn, s, why, speed)
	if s.mode ~= WALKING then
		if Trial.open() then Trial.say("%s off the ground (mode %s): no slide", why, f(s.mode)) end
		return false
	end
	local anim = Anim.anim(pawn)
	local objs = { start = Sets.load(say, Sets.SLIDE.start), loop = Sets.load(say, Sets.SLIDE.loop) }
	if anim == nil or objs.start == nil or objs.loop == nil then return false end
	S.n = S.n + 1
	local plan, what = Tilt.plan()
	local moving = (s.speed or 0) > MOVING and s.vx ~= nil
	local yaw = moving and math.deg(math.atan(s.vy, s.vx)) or (s.yaw or 0)
	-- speed: without the speed setting (slide_motion.lua); push: the speed written.
	local w = { n = S.n, t0 = now, anim = anim, objs = objs, yaw = yaw, pos0 = s.pos, loops = 0, next_log = now,
		push_failed = 0, speed = Motion.start_speed(speed), f = C.speed, length = C.length, held = 0, slowed = 0 }
	w.k = Motion.gain(w.speed, w.f)
	w.push = Motion.pushed(w.speed, w.k, w.f)
	w.top = w.push
	if not enter(w, now, "start") then
		say("slide #%d: the first animation did not play, no slide", w.n)
		return false
	end
	S.slide = w
	Sound.start(say, pawn)
	if Trial.open() then
		Trial.say("slide #%d start (%s) by %s: speed=%s->%s (speed x%.1f, length x%.1f) yaw=%.0f slope=%s at %s", w.n,
			what, why, f(speed), f(w.push), w.f, w.length, yaw, f(floor_angle(floor_normal(s.cmc), yaw), "%.1f"),
			R.vec_text(s.pos))
	end
	Anim.ignore_root_motion(say, anim)
	Control.hold(say, s.cmc)
	Tilt.begin(say, w.n, plan)
	return true
end

-- A button: a slide only while running on the ground, and none while one runs. speed: at a landing, the jump's
-- speed, taken when faster than the landing's. Returns true when the slide started.
function M.button(say, now, pawn, s, name, speed)
	if S.slide ~= nil then return false end
	local v = math.max(s.speed or 0, speed or 0)
	if v < RUNNING then
		if Trial.open() then Trial.say("%s at speed %s: not running, no slide", name, f(v)) end
		return false
	end
	return press(say, now, pawn, s, name, v)
end

function M.running()
	return S.slide ~= nil
end

-- The player ends the slide: why, the button pressed again.
function M.release(why)
	if S.slide ~= nil then S.slide.released = why end
end

-- With SlideHold, whether a button is held this frame: held, the slide keeps its speed (slide_trigger.lua).
function M.hold(on)
	S.holding = on
end

-- The floor's normal for the player's state s, nil off the ground (the tilt reads it too, slide_ground.lua).
function M.floor(s)
	return s.mode == WALKING and floor_normal(s.cmc) or nil
end

-- The settings the next slide takes (slide_settings.lua); a slide under way keeps its own.
function M.configure(settings)
	C.speed, C.length = settings.speed, settings.length
end

-- look(): the player's state and the floor's normal this frame, read only while a slide runs.
function M.frame(say, now, dt, pawn, look)
	local w = S.slide
	if w == nil then return end
	local s, normal = look()
	if not R.is_valid(w.anim) then return finish(say, now, s, "animation instance gone", false) end
	local m, ours = Anim.current(w.anim)
	if m ~= nil and not ours then return finish(say, now, s, "cut by " .. Anim.name(m), false) end
	if s.mode ~= WALKING then return finish(say, now, s, "left the ground (mode " .. f(s.mode) .. ")", true) end
	local angle = floor_angle(normal, w.yaw)
	if angle ~= nil then w.low, w.high = math.min(w.low or angle, angle), math.max(w.high or angle, angle) end
	if w.released and now - w.t0 >= Motion.MIN_TIME then return finish(say, now, s, w.released, true) end
	-- The start frame is not in the slide's time (now - t0) either.
	if S.holding and now > w.t0 then w.held = w.held + dt end
	if not S.holding and w.held >= Motion.HOLD_TIME then return finish(say, now, s, "let go", true) end
	-- Slowed down to the game's jog, the slide is over at once, whatever MIN_TIME says.
	local blocked, slowed = Blocked.check(w, s.pos)
	if slowed ~= nil then w.speed, w.slowed = Motion.unpushed(slowed, w.k), w.slowed + 1 end
	if blocked or (slowed ~= nil and w.speed < Motion.END_SPEED) then
		local why = blocked and "blocked" or "slowed to running speed"
		return finish(say, now, s, string.format("%s, moving at %s for %s pushed", why, f(w.moved), f(w.written)), true)
	end
	local over = Motion.end_reason(w.speed, now - w.t0, now - w.t0 - w.held, w.length)
	if over ~= nil then return finish(say, now, s, over, true) end
	if now >= w.phase_end and not enter(w, now, "loop") then
		return finish(say, now, s, "the loop animation did not play", true)
	end
	w.yaw = steer(pawn, w.yaw, dt)
	w.speed = Motion.next_speed(w.speed, angle, dt, w.length, S.holding)
	w.push = Motion.pushed(w.speed, w.k, w.f)
	w.top = math.max(w.top, w.push)
	Control.frame()
	push(pawn, s, w)
	-- The game moves the character at this speed over this frame's time, seen at the next frame (slide_blocked.lua).
	w.written, w.written_dt = w.push, dt
	if now >= w.next_log and Trial.open() then
		w.next_log = now + LOG_EVERY
		Trial.say("s#%d t=%.2f %s wanted=%s kept=%s moved=%s slope=%s mode=%s z=%s anim=%s %s", w.n, now - w.t0,
			w.phase, f(w.push), f(s.speed), f(w.moved), f(angle, "%.1f"), f(s.mode), f(s.pos and s.pos.z),
			m and Anim.name(m) or "none", Tilt.text())
	end
end

-- A slide in progress is dropped, the character's settings put back. why: a new pawn (load, respawn), or the mod
-- switched off; stop: the same pawn, whose slide animation is stopped too (left playing, its own motion would carry
-- the character on, audit of 0.5.2).
function M.reset(say, why, stop)
	local w = S.slide
	if w == nil then return end
	S.slide = nil
	if stop then Anim.stop(w.anim) else Anim.forget() end
	Anim.restore_root_motion(say)
	Control.release(say)
	Sound.stop(say, false)
	say("slide dropped: %s", why)
end

return M
