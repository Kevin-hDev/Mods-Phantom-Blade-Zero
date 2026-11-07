-- How an air jump's dodge ends (1.0.5).
-- The game itself lets go of a dodge a moment before its end: the character stops moving by the animation, and keeps
-- the speed it had, the game having no braking in the air (BrakingDecelerationFalling and FallingLateralFriction 0,
-- trace of 5 November 2026). The double jump is let go that way while it still moves fast once its speed passes about
-- 2.3, and glides to the ground. The triple jump's animation ends on a strong slowing (1,650 to 150 in a tenth of a
-- second at speed 3), which a high speed plays in the air: the character stopped dead, "un ressenti vraiment
-- désagréable" (Kevin, same day). So above speed 1, the mod lets go of the triple jump just before that slowing, and
-- it glides like the double, with a little less of its speed; and the double, once the game lets go of it, keeps no
-- more speed than the triple. At 1, nothing changes from 1.0.4 (the slowing comes after landing most of the time),
-- and nothing is followed: at its neutral value, the setting reads nothing of the game in the air (the rate read back
-- once per dodge and speed aside).
-- Said once per dodge and speed: the rate the game reads back, and how long before landing the dodge ended.

local U = require("dodge_jump_unreal")
local Objects = require("dodge_jump_objects")

local M = {}

-- Montage seconds where the mod lets go of each dodge, in the order of dodge_jump_air.lua's DODGES; nil: never. The
-- triple jump's speed holds near its top to about 0.83 s, then falls (trace of 5 November 2026, speeds 2 to 3).
M.LET_GO_AT = { nil, 0.80 }
-- Seconds the dodge's pose takes to give way to the fall, close to the game's own for the double jump (about 0.36 s).
local BLEND_OUT = 0.3
-- Share of its speed a dodge keeps once the mod lets go of it: all of it pushed a little too far (Kevin, 5 November
-- 2026: "on peut réduire un peu la poussée sur la fin ?", after 1,645 kept at speed 2.5). Set through
-- LaunchCharacter, the call that already pushes each air jump up, on the speed along the ground only.
M.CARRY = 0.8
-- The triple jump's speed along the ground where the mod lets go of it, per unit of speed setting: 655 to 659 (1,310
-- at 2, 1,648 at 2.5, 1,968 at 3; traces of 5 November 2026).
local TRIPLE_SPEED_PER_RATE = 657
-- Dodges that keep, once the game has let go of them in the air, no more than a triple jump let go at the same speed
-- setting: the double jump, let go before its own slowing above about 2.3, kept 1,940 to 1,970 at 2.5 to the triple's
-- 1,308 (Kevin, 5 November 2026: "pour le double elle pousse encore trop fort, faudrait qu'elle pousse comme pour le
-- triple"). Slower, as at 2 (540 to 580), it is left alone. Same order as LET_GO_AT.
M.CAP_AT_END = { true, false }
local NAMES = { "double", "triple" }

-- watch: the last dodge played, followed until landing. Its keys: m, which (1 double, 2 triple), rate, let_go (montage
-- seconds, or nil), cap (the most speed along the ground it keeps once the game lets go of it, or nil), ended (the
-- clock when it was seen ended, or nil), unanswered (true while the game gives no answer on it).
-- The *_said tables are keyed by dodge and speed: 2 dodges, 21 speeds at most (dodge_jump_settings.lua keeps tenths).
local E = { watch = nil, rate_said = {}, end_said = {}, let_go_said = {}, cap_said = {}, no_follow = false,
	no_position = false, gone = false, stop_failed = false, carry_failed = false }

local function key(w)
	return string.format("%d:%g", w.which, w.rate)
end

local function anim_of(pawn)
	local anim = nil
	pcall(function() anim = pawn.Mesh:GetAnimInstance() end)
	return U.is_valid(anim) and anim or nil
end

local function once(flag, log, message)
	if E[flag] then return end
	E[flag] = true
	log("%s; said once", message)
end

-- A dodge just played at rate.
function M.start(pawn, m, which, rate, log)
	if E.rate_said[which] ~= rate then
		E.rate_said[which] = rate
		local read = nil
		pcall(function() read = U.num(anim_of(pawn):Montage_GetPlayRate(m)) end)
		log("%s jumps play at speed %g (the game reads back %s)", NAMES[which], rate,
			read ~= nil and string.format("%.2f", read) or "nothing")
	end
	if rate <= 1 then
		E.watch = nil
		return
	end
	E.watch = { m = m, which = which, rate = rate, let_go = M.LET_GO_AT[which],
		cap = M.CAP_AT_END[which] and M.CARRY * TRIPLE_SPEED_PER_RATE * rate or nil, ended = nil }
end

-- The speed along the ground times share, and no more than most (nil: no bound); up and down untouched. Returns the
-- speed along the ground before and after, or nothing when it is left as it is.
local function lower(pawn, share, most, log)
	local vx, vy = nil, nil
	pcall(function()
		local v = pawn.CharacterMovement.Velocity
		vx, vy = U.num(v.X), U.num(v.Y)
	end)
	if vx ~= nil and vy ~= nil then
		local along = math.sqrt(vx * vx + vy * vy)
		if most ~= nil and along * share > most then share = most / along end
		if share >= 1 or along == 0 then return nil end
		if pcall(function()
			pawn:LaunchCharacter({ X = vx * share, Y = vy * share, Z = 0 }, true, false)
		end) then return along, along * share end
	end
	once("carry_failed", log, "could not lower the speed a dodge keeps once it ends: it keeps all of it")
	return nil
end

local function let_go(pawn, anim, w, pos, log)
	w.let_go = nil
	if not pcall(function() anim:Montage_Stop(BLEND_OUT, w.m) end) then
		once("stop_failed", log, "could not let go of a dodge before its slowing: it ends as the game plays it")
		return
	end
	local from, to = lower(pawn, M.CARRY, nil, log)
	if E.let_go_said[key(w)] then return end
	E.let_go_said[key(w)] = true
	log("%s jump at speed %g: let go at %.2f s of its dodge%s", NAMES[w.which], w.rate, pos,
		from ~= nil and string.format(", its speed along the ground lowered from %.0f to %.0f", from, to) or "")
end

-- The game let go of a dodge in the air: no more speed along the ground than w.cap.
local function cap(pawn, w, log)
	local from, to = lower(pawn, 1, w.cap, log)
	if from == nil or E.cap_said[key(w)] then return end
	E.cap_said[key(w)] = true
	log("%s jump at speed %g: ended in the air, its speed along the ground lowered from %.0f to %.0f",
		NAMES[w.which], w.rate, from, to)
end

-- Each frame in the air: notes when the dodge ends, and lets go of it where it should.
function M.frame(pawn, now, log)
	local w = E.watch
	if w == nil or w.ended ~= nil then return end
	-- Kept since its jump: checked again before each use (dodge_jump_objects.lua).
	if not Objects.usable(w.m, Objects.MONTAGE) then
		E.watch = nil
		once("gone", log, "a dodge followed in the air is gone from the game: it is left alone")
		return
	end
	local anim = anim_of(pawn)
	local playing = nil
	if anim ~= nil then pcall(function() playing = anim:Montage_IsPlaying(w.m) end) end
	-- A frame without an answer is not the end of the dodge: asked again at the next one.
	w.unanswered = type(playing) ~= "boolean"
	if w.unanswered then
		once("no_follow", log, "could not follow a dodge in the air for a frame: asked again at each frame")
		return
	end
	if not playing then
		w.ended = now
		if w.cap ~= nil then cap(pawn, w, log) end
		return
	end
	if w.let_go == nil then return end
	local pos = nil
	pcall(function() pos = U.num(anim:Montage_GetPosition(w.m)) end)
	if pos == nil then
		once("no_position", log, "could not read where a dodge is in the air: it is let go once it can be read")
		return
	end
	if pos >= w.let_go then let_go(pawn, anim, w, pos, log) end
end

-- Landing: how the last dodge ended, said once per dodge and speed.
function M.landed(now, log)
	local w = E.watch
	E.watch = nil
	-- The game's last answer missing: nothing known of how it ended.
	if w == nil or w.unanswered then return end
	if E.end_said[key(w)] then return end
	E.end_said[key(w)] = true
	log("%s jump at speed %g: its dodge %s", NAMES[w.which], w.rate,
		w.ended ~= nil and string.format("ended %.2f s before landing", now - w.ended) or "was still playing at landing")
end

-- Takeoff: no dodge of ours yet.
function M.reset()
	E.watch = nil
end

return M
