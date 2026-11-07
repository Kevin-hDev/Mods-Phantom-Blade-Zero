-- What the tilt (slide_tilt.lua) measured and did during one slide, written when the slide ends: the lifted foot, its
-- height above the planted one without the lean, how far behind and beside it is, the lean wanted and reached, the
-- move along the floor's normal wanted and reached, the lift the player saw with the lean, and what the game changed
-- meanwhile. Only a trial build writes it (slide_trial.lua).

local R = require("slide_reading")

local M = {}

local f = R.f
-- s: the lean wanted and reached is kept this often from the slide's start, for this long, to see its start.
local CURVE_EVERY, CURVE_FOR = 0.025, 0.4

local function clear(s)
	s.locked, s.lift, s.top_lift, s.behind, s.side, s.want, s.top_want, s.top_at = 0, 0, 0, 0, 0, 0, 0, nil
	s.seen, s.seen_untilted, s.seen_n = 0, 0, 0
	s.up, s.up_n, s.up_lo, s.up_hi, s.by_toe = 0, 0, nil, nil, 0
end

-- plan: what the slide turns off while it leans, nil when it does not lean (slide_tilt.lua).
function M.describe(plan)
	return plan and ("lean, " .. plan .. " off") or "no lean"
end

-- read, drop: the planted ankle's height above the mesh's origin read while running, and its toe's drop below it
-- (slide_ground.lua), nil when not read.
function M.new(n, plan, read, drop)
	local s = { n = n, plan = plan, lean = plan ~= nil, read = read, drop = drop, frames = 0, unread = 0, switches = 0,
		rewrites = 0, top_applied = 0, top_moved = 0, curve = {}, curve_at = 0 }
	clear(s)
	return s
end

-- The lifted foot changed: what was measured on the other one is dropped.
function M.switched(s)
	s.switches = s.switches + 1
	clear(s)
end

-- d: the lifted foot minus the planted one, in the actor's space.
function M.foot(s, lift, d)
	s.locked, s.lift, s.behind, s.side = s.locked + 1, s.lift + lift, s.behind - d.x, s.side + d.y
	s.top_lift = math.max(s.top_lift, lift)
end

-- The lean wanted, the lift and how far behind the lifted foot is: where the most wanted lean came from is kept.
function M.want(s, want, lift, behind)
	s.want = s.want + want
	if s.top_at ~= nil and want <= s.top_want then return end
	s.top_want, s.top_at = want, string.format("frame %d, lift %s behind %s cm", s.frames, f(lift), f(behind))
end

function M.up(s, up, by_toe)
	s.up, s.up_n = s.up + up, s.up_n + 1
	if by_toe then s.by_toe = s.by_toe + 1 end
	s.up_lo, s.up_hi = math.min(s.up_lo or up, up), math.max(s.up_hi or up, up)
end

-- What the mesh got this frame: the lean and the move along the normal.
function M.applied(s, lean, moved)
	s.top_applied = math.max(s.top_applied, lean)
	if math.abs(moved) > math.abs(s.top_moved) then s.top_moved = moved end
end

-- t: the time since the slide's start; want, leaned: the lean wanted and reached this frame.
function M.curve(s, t, want, leaned)
	if t < s.curve_at or s.curve_at > CURVE_FOR then return end
	while s.curve_at <= t do s.curve_at = s.curve_at + CURVE_EVERY end
	s.curve[#s.curve + 1] = string.format("%.3f %.0f/%.0f", t, want, leaned)
end

function M.seen(s, lift, untilted)
	s.seen, s.seen_untilted, s.seen_n = s.seen + lift, s.seen_untilted + untilted, s.seen_n + 1
end

-- held: what was turned off of the game's foot placement (slide_placement.lua).
function M.write(say, s, foot, held)
	local k = s.locked > 0 and s.locked or nil
	local n = s.seen_n > 0 and s.seen_n or nil
	local u = s.up_n > 0 and s.up_n or nil
	local function avg(sum, count) return count and sum / count or nil end
	say("tilt #%d %s: lifted foot %s on %d of %d frames, %d switches; untilted lift avg=%s max=%s cm, behind=%s "
		.. "side=%s cm; lean wanted avg=%s max=%s deg (%s), leaned max=%s deg; planted ankle read %s cm above the mesh "
		.. "while running, toe %s cm below it; move wanted avg=%s from %s to %s cm (the toe deciding %d frames), moved "
		.. "most %s cm; lift seen avg=%s cm for untilted %s cm; mesh moved by the game %d; %s; unreadable %d",
		s.n, M.describe(s.plan), foot, s.locked, s.frames, s.switches, f(avg(s.lift, k)),
		f(k and s.top_lift), f(avg(s.behind, k)), f(avg(s.side, k)), f(avg(s.want, k), "%.1f"),
		f(k and s.top_want, "%.1f"), s.top_at or "none", f(s.top_applied, "%.1f"), f(s.read), f(s.drop),
		f(avg(s.up, u)), f(s.up_lo), f(s.up_hi), s.by_toe, f(s.top_moved), f(avg(s.seen, n)),
		f(avg(s.seen_untilted, n)), s.rewrites, held, s.unread)
	if #s.curve > 0 then
		say("tilt #%d start, lean wanted/reached every %d ms: %s", s.n, math.floor(CURVE_EVERY * 1000 + 0.5),
			table.concat(s.curve, ", "))
	end
end

return M
