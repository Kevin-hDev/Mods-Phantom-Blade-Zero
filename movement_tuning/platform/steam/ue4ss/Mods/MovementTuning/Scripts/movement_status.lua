-- The status line: one line per move would flood the log, so counts and the mod's cost are written every EVERY
-- seconds. No word a mod manager takes for an error unless there is one: mod managers paint red any line with
-- error(s), failed, failure, exception or fatal, and yellow warn(ing)(s), even "0 errors". The errors are those since
-- the last line.

local Tasks = require("movement_tasks")
local Speed = require("movement_speed")
local Timeline = require("movement_timeline")
local Ground = require("movement_ground")
local Sprints = require("movement_sprints")
local Resume = require("movement_resume")
local SprintOff = require("movement_sprint_off")
local Enemies = require("movement_enemies")

local M = {}

M.EVERY = 600    -- seconds between two status lines

-- S: main.lua's counts since the last line (calls, busy, tasks, pushes, window_errors, longest, slow), started over
-- here, and next_status. slow_call: the length, in seconds, past which a call is counted. log: as main.lua's.
function M.write(S, now, slow_call, log)
	if S.next_status == nil then S.next_status = now + M.EVERY end
	if now < S.next_status then return end
	S.next_status = now + M.EVERY
	local enemies, enemy_errors = Enemies.report()
	S.window_errors = S.window_errors + Tasks.errors() + enemy_errors
	local parts = {}
	for key, n in pairs(S.pushes) do parts[#parts + 1] = string.format("%s %d", key, n) end
	table.sort(parts)
	local moving = Ground.report() .. "; " .. Sprints.report() .. "; " .. Resume.report() .. "; " .. SprintOff.report()
		.. "; " .. enemies
	log("status: in the last %d minutes, frames paced: %s; %s; %d calls (%.0f a second), %d tasks looked at, "
		.. "%d known, %d timelines unreadable, %.1f microseconds a call on average, longest %.0f ms (1 ms clock), %d "
		.. "over %.0f ms%s",
		M.EVERY // 60,
		#parts > 0 and table.concat(parts, ", ") or "none", moving, S.calls, S.calls / M.EVERY,
		S.tasks, Speed.remembered(), Timeline.report(),
		S.calls > 0 and S.busy / S.calls * 1e6 or 0, S.longest * 1e3, S.slow, slow_call * 1e3,
		S.window_errors > 0 and string.format(", %d errors", S.window_errors) or "")
	S.calls, S.busy, S.tasks, S.pushes, S.window_errors, S.longest, S.slow = 0, 0, 0, {}, 0, 0, 0
end

return M
