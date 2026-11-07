-- How fast the slide goes, frame by frame. Kevin, 4 November 2026: a slide on one button, on the ground only, on flat
-- ground, downhill and uphill. On flat ground it slows down by itself; downhill, gravity along the slope works against
-- the slowing, so a steep slope keeps it going or speeds it up; uphill, gravity adds to the slowing.
-- It ends while still moving, at about the game's jog speed, so the character goes on running: stopping dead and
-- standing up on the spot looked wrong (first trial, "une animation bizarre à la fin").
--
-- Two settings, 1 to 3, taken when a slide starts (slide_settings.lua; Kevin, 5 November 2026):
-- length L: the slowing on flat ground is divided by L and the longest slide lasts L times as long, so a slide on
-- flat ground lasts and goes about L times as long ("glisser plus longtemps").
-- speed f: the slide starts f times as fast and still hands over to the game's running at END_SPEED, in the same time
-- as without the setting. The speed written is END_SPEED + k x (the speed without the setting - END_SPEED), k chosen
-- at the start (M.gain): multiplied all along, the slide would hand over at f x END_SPEED, and the game's running
-- would brake it at once.
-- Held (the SlideHold setting, slide_trigger.lua; Kevin, 5 November 2026: "le slide continue tant que la touche est
-- maintenue en conservant sa vitesse", varying on flat ground, downhill and uphill, "et bien sûr que ça s'arrête quand
-- y'a perte de vitesse dans les montées raides"): while the button is held, no slowing on flat ground, only the
-- slope's gravity, and the longest slide counts only the time not held. Held, the slide ends when an uphill brings it
-- down to END_SPEED; let go after HOLD_TIME, it ends (slide_run.lua), a shorter press being a click, the normal slide.

local M = {}

M.MIN_START = 1000                -- the slowest start (jog 600, sprint 750, super sprint 950)
M.START_BOOST = 1.2               -- a slide from a run starts a little faster than the run
M.MAX_SPEED = 1800                -- without the speed setting; f times this with it
M.FLAT_DECEL = 450                -- cm/s² on flat ground: 1000 down to 550 in 1 s, about 7.5 m
M.GRAVITY = 980 * 2.2             -- the player's GravityScale is 2.2 (MoveProbe, 4 November 2026)
M.SLOPE_GAIN = 1.0                -- share of that gravity along the slope; downhill it beats the slowing past ~12°
M.MIN_TIME = 0.4                  -- no end before this, so a slide started uphill still shows
-- Held this long, a slide is a held one and ends when let go; shorter, a click. Kevin, 5 November 2026, of a slide
-- held 0.8 s that went on: "il ne s'est pas arrêté quand j'ai lâché le bouton" (trial of 0.4.0).
M.HOLD_TIME = 0.4
M.MAX_TIME = 3.0                  -- a long downhill ends here, L times this with the length setting, time held
                                  -- not counted
M.END_SPEED = 550                 -- the slide hands over to the game's running near its jog speed

function M.start_speed(current)
	return math.min(math.max((current or 0) * M.START_BOOST, M.MIN_START), M.MAX_SPEED)
end

-- The ground's slope along the flat direction (dx, dy), in degrees from the floor's normal n: positive when the
-- ground goes down ahead, negative uphill, nil when the normal is unusable.
function M.slope(n, dx, dy)
	if n == nil or n.z == nil or n.z <= 0.05 then return nil end
	return math.deg(math.atan(n.x * dx + n.y * dy, n.z))
end

-- The speed without the speed setting, a frame later. keep: the button held, no slowing on flat ground.
function M.next_speed(speed, angle, dt, length, keep)
	local along = M.GRAVITY * M.SLOPE_GAIN * math.sin(math.rad(angle or 0))
	local flat = keep and 0 or M.FLAT_DECEL / length
	return math.min(math.max(speed + (along - flat) * dt, 0), M.MAX_SPEED)
end

-- Why the slide ends now, or nil. speed: without the speed setting; t: since the start; free: of t, the time the
-- button was not held.
function M.end_reason(speed, t, free, length)
	if free >= M.MAX_TIME * length then return "time limit" end
	if t >= M.MIN_TIME and speed < M.END_SPEED then return "faded into running" end
	return nil
end

-- k for a slide whose speed without the setting starts at start (start_speed: at least MIN_START, above END_SPEED).
function M.gain(start, f)
	return (start * f - M.END_SPEED) / (start - M.END_SPEED)
end

-- The speed written into the character for the speed without the setting; below END_SPEED, that speed itself.
function M.pushed(speed, k, f)
	if speed <= M.END_SPEED then return speed end
	return math.min(M.END_SPEED + k * (speed - M.END_SPEED), M.MAX_SPEED * f)
end

-- The speed without the setting that gives the speed written push: pushed's inverse.
function M.unpushed(push, k)
	if push <= M.END_SPEED then return push end
	return M.END_SPEED + (push - M.END_SPEED) / k
end

return M
