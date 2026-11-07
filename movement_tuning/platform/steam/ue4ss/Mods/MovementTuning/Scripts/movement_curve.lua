-- The left stick's curve, as arithmetic only: where the locomotion ability cuts the stick into walk and run (written by
-- movement_stick.lua), and the speed allowed for a push of the stick (written by movement_ground.lua). The push here is
-- the stick the ability reads, after the dead zone: 0 at the dead zone's edge, 1 at the end of the stick's travel.

local M = {}

-- The game takes a run back to a walk 0.08 below the run's cut (0.35 and 0.43, verified in game): kept, so a
-- stick held near the run point does not switch from one gait to the other.
local DOWNSHIFT_GAP = 0.08
local FULL = 0.95         -- this push is the full run: a worn stick may not reach 1
local MIN_STICK = 0.02    -- a stick let go: the game's speed, so stopping keeps the game's feel
M.MIN_STICK = MIN_STICK
local IMPOSED = 0.6       -- a game speed under 0.6 x the walk's is one the game imposes (a story walk): left to it
local RUN_SHARE = 0.6     -- the run's slowest is 1 - (1 - slowest walk) x 0.6 of the run: 0.7 at Smooth's 0.5
local SAME = 0.5          -- a game speed this close to a gait's is that gait's

-- Smooth, the preset (percents, as in the settings file). Its walk never goes above the game's
-- walk speed: the mod does not speed the walk animation up, and faster its feet would slide.
M.SMOOTH = { dead = 8, run_point = 72, slowest = 50, curve = 1.0 }

-- The left stick's settings, from the file's percents: dead (the dead zone), run_point (how far the stick goes before the
-- run starts, as a share of its travel), slowest (the walk's speed at the first push, as a share of the game's walk),
-- curve (above 1, more of the stick's travel for the slow speeds). Adds the cuts the ability gets: run and walk on the
-- push, and delay, the seconds the game waits before a walk starts: 0, the game's 0.25 s made a short push do nothing.
function M.left(dead, run_point, slowest, curve)
	local d, r = dead / 100, run_point / 100
	local run = (r - d) / (1 - d)
	local s = slowest / 100
	return { dead = d, run_point = r, slowest = s, curve = curve, run = run,
		walk = math.max(run - DOWNSHIFT_GAP, MIN_STICK), delay = 0, run_floor = 1 - (1 - s) * RUN_SHARE }
end

local function lerp(a, b, t) return a + (b - a) * t end

local function share(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return t
end

-- The speed allowed for the game's speed base and the push p (nil when the stick was not read), never above base. base
-- is a gait's speed, or between two while the game eases from one to the next. gaits: { walk, run, sprint }.
function M.speed(base, p, gaits, left)
	if p == nil or p < MIN_STICK or base < gaits.walk * IMPOSED or base > gaits.run + SAME then return base end
	local want
	-- The game's run stays a run when it comes back with the stick already below the walk's cut (end of a sprint): given
	-- the walk's speed there, the run animation plays in slow motion. The game's gait decides.
	if base <= gaits.walk + SAME then
		want = gaits.walk * lerp(left.slowest, 1, share(p / left.run) ^ left.curve)
	else
		local t = share((p - left.walk) / (FULL - left.walk)) ^ left.curve
		want = math.max(gaits.walk, gaits.run * lerp(left.run_floor, 1, t))
	end
	return math.min(base, want)
end

return M
