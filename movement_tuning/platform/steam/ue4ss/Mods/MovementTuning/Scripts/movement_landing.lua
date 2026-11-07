-- A dodge's landing on the ground, paced: movement_dodge.lua tells its fall, its speeds frame by frame and its end.
-- From the fall until the game takes the stick, the dodges' timelines are paced frame by frame to hold the character at
-- a speed that goes with the dodges' pace (HELD; the speed allowed at most, MaxWalkSpeed, which the sprint resume gives
-- back): the speed of a frame comes from the pace of the frame before, so the next pace is that one times the speed
-- held over the speed reached. The timeline is what moves a dodge: pushed (movement_speed.lua), the whole flip goes
-- faster over the same ground, its speeds with it; the montage's own play rate is not followed (1.0.5), and cutting the
-- animation broke its look (1.0.3). A fixed 3 times (1.0.6) made the speed jump, 450, 800, 300, then 600 with the stick
-- back: the character seemed to pop (Kevin, 6 November 2026).

local Moves = require("movement_moves")

local M = {}

local HELD = 460        -- a landing's speed held for each unit of the dodges' pace: about 600 at Dodges 1.3, right
                        -- (Kevin, trial of 1.0.7); held at 600 at the game's pace too, it was over in 0.13 s, too
                        -- abrupt there: 460 takes 0.17 s in the tests (Kevin asked 0.16 to 0.18)
local STEP, STEP_TIME = 1.5, 1 / 60 -- a landing's pace changes at most STEP times in STEP_TIME s, either way: the speed
                                    -- follows without a jolt, at any frame rate (1.0.7 allowed STEP each frame; the
                                    -- game ran at over 120 a second and the pace swung from 2 to 3 and back)
local TIMES = 3         -- a landing's pace at most this many times the dodges' setting: up to 8 (1.0.8), the last
                        -- frames of both flips, where the character straightens up and hardly moves, went 4 to 8 times
                        -- as fast and the torso seemed to jerk, seen from the front (Kevin, 6 November 2026); at 3
                        -- times, the first flip's landing keeps its length (0.17 s at the game's pace, 0.13 at 1.3)
local MAX_LINES = 5     -- landings written to the log for the same settings
local MAX_FRAMES = 32   -- frames of a landing written to the log: 0.17 s at 144 frames a second makes 25

-- L: the landing followed, nil when none. at: the clock of its fall. from, toward, held: the speed then, the speed
-- allowed and the speed held. speed, allowed: this frame's. rate: the pace of the last frame. paces, speeds: frame by
-- frame, for the log.
local L = nil
-- lines: landings written to the log for the settings said_for. landings: since the last status line. faster: the
-- speeds while a dodge lands, copied once from the settings' speeds (from).
local lines, landings, said_for = 0, 0, nil
local faster = { from = nil, rates = nil }

function M.forget()
	L = nil
end

-- The settings this frame: a change gives the log MAX_LINES lines again.
function M.settings(rates)
	if rates ~= said_for then said_for, lines = rates, 0 end
end

function M.following()
	return L ~= nil
end

-- Whether the landing followed will be written to the log: what only the log needs is read only then.
function M.writes()
	return L ~= nil and lines < MAX_LINES
end

-- The fall: the speed then and the speed allowed (nil when unreadable).
function M.start(now, speed, allowed)
	landings = landings + 1
	L = { at = now, from = speed, toward = allowed, held = nil, speed = speed, allowed = allowed, rate = nil, paces = {},
		speeds = {} }
end

-- This frame's speed and speed allowed, nil when unreadable.
function M.read(speed, allowed)
	if L ~= nil then L.speed, L.allowed = speed, allowed end
end

local function shown(v)
	return v and string.format("%.0f", v) or "?"
end

-- The landing is over: written to the log once (MAX_LINES lines at most for the same settings), frame by frame. name,
-- since: the dodge's montage and when it started. after: what ended it, and speed the speed then (nil: not said).
function M.finish(now, say, name, since, after, speed)
	local l = L
	if l == nil then return end
	L = nil
	if lines >= MAX_LINES then return end
	lines = lines + 1
	local paces, speeds = {}, {}
	for k, rate in ipairs(l.paces) do
		paces[k] = string.format(" %.2f", rate)
		speeds[k] = " " .. shown(l.speeds[k])
	end
	if speed ~= nil then after = after .. " at " .. shown(speed) end
	say("dodge landing: %s at %.2f s, speed %.0f (held at %s, allowed %s); %.2f s, paced%s, speeds%s; then %s", name,
		l.at - since, l.from, shown(l.held), shown(l.toward), now - l.at, table.concat(paces), table.concat(speeds),
		after)
end

-- This frame's pace: the pace of the frame before times the speed held over the speed reached, kept when the speed
-- cannot be read; never under the dodges' setting (base), within STEP in STEP_TIME of the frame before (dt: the time
-- since), TIMES the setting at most.
local function paced(l, base, held, dt)
	local last = l.rate or base
	local top = TIMES * base
	local rate = last
	if l.speed ~= nil then rate = l.speed > 1 and held * last / l.speed or top end
	local step = (dt ~= nil and dt > 0) and STEP ^ (dt / STEP_TIME) or 1
	return math.max(base, last / step, math.min(top, last * step, rate))
end

-- The speeds the player's timelines follow: rates itself, the dodges' paced while a landing is followed. dt: the time
-- since the last frame. Called once a frame, after the landing's speeds are read: its pace moves on at each call.
function M.rates(rates, dt)
	local l = L
	if l == nil then return rates end
	local base = rates[Moves.DODGES] or 1
	-- The speed allowed unreadable, the speed held alone: the landing still paced.
	local held = l.allowed and math.min(l.allowed, HELD * base) or HELD * base
	l.held = l.held or held
	l.rate = paced(l, base, held, dt)
	if lines < MAX_LINES and #l.paces < MAX_FRAMES then
		l.paces[#l.paces + 1], l.speeds[#l.speeds + 1] = l.rate, l.speed or false
	end
	if faster.from ~= rates then
		local copy = {}
		for key, rate in pairs(rates) do copy[key] = rate end
		faster.from, faster.rates = rates, copy
	end
	faster.rates[Moves.DODGES] = l.rate
	return faster.rates
end

-- Landings paced since the last call, for the status line.
function M.report()
	local n = landings
	landings = 0
	return n
end

return M
