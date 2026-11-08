-- A measure and its plan spread over frames, at most BUDGET traces a frame. Each trace called from Lua costs about
-- 40 us, 30 of them before the engine looks for anything (measured in game), and a press makes 30 to 60: in one
-- frame, 1.8 to 1.9 ms on average, up to 4 ms. The plan is only used 0.1 s after the press, about twelve frames:
-- the same traces, from the same points, can be made over a few of them.
--
-- How, without a Lua coroutine: UE4SS finds the mod behind each call by the calling Lua state, and a coroutine's state
-- is one it does not know, so every call to the game from one would fail (LuaMadeSimple.cpp, process_lua_function).
-- Instead the whole work runs again on each frame from its start: the traces of the frames before come back from
-- memory, in the order they were made, and once the frame's budget is spent the next trace stops the work with OVER,
-- to go on at the next frame. The work reads the world only through Measure.trace and reads the
-- character only once (at), so a run gives what a single frame would have. A hit kept for later frames holds its
-- touched object as UE4SS copies it, a weak pointer that checks the object still lives (push_weakobjectproperty).
-- Nothing may catch OVER on its way out: no pcall stands between the traces and step.

local M = {}

M.BUDGET = 20                     -- traces a frame: about 0.8 ms at 40 us each
-- Thrown by a trace past the frame's budget. A table, so that nothing else is taken for it.
M.OVER = setmetatable({}, { __tostring = function() return "the frame's traces are spent" end })

-- current: the work running in this frame; n: the traces it asked for in this run; left: those it may still make.
local S = { current = nil, n = 0, left = 0 }

-- A work: fn(work) runs the measure and the plan from the start and returns what they give; work.pawn is the
-- character of the frame it runs in. at: what the work reads once, kept for its later runs.
function M.new(fn, now)
	return { fn = fn, t = now, traces = {}, at = {}, frames = 0, done = false, result = nil, pawn = nil }
end

local function same(k, a, b, channel)
	return k.ax == a.X and k.ay == a.Y and k.az == a.Z and k.bx == b.X and k.by == b.Y and k.bz == b.Z
		and k.channel == channel
end

-- One frame of the work on pawn: true once it has ended (work.result holds what fn gave), false when it goes on at
-- the next frame. An error of fn is raised again, the work left as it was.
function M.step(work, pawn)
	S.current, S.n, S.left = work, 0, M.BUDGET
	work.frames, work.pawn = work.frames + 1, pawn
	local res = table.pack(pcall(work.fn, work))
	S.current = nil
	if res[1] then
		work.done, work.result = true, table.pack(table.unpack(res, 2, res.n))
		return true
	end
	if res[2] == M.OVER then return false end
	error(res[2], 0)
end

-- For Measure.trace, before it traces from a to b: { hit = ... } when an earlier run of the work made this very trace
-- at this place, else nil, and it may be made now. Stops the work (OVER) once the frame's budget is spent. A run that
-- asks for another trace than the one kept at its place (a setting changed between two frames) traces anew there; a
-- kept trace that is the same as the one asked gives what it gave, wherever the runs part.
function M.recall(a, b, channel)
	local w = S.current
	if w == nil then return nil end
	S.n = S.n + 1
	local kept = w.traces[S.n]
	if kept ~= nil and same(kept, a, b, channel) then return kept end
	if S.left <= 0 then error(M.OVER, 0) end
	S.left = S.left - 1
	return nil
end

-- For Measure.trace, once it has traced: what it got, kept for the work's next runs.
function M.keep(a, b, channel, hit)
	local w = S.current
	if w == nil then return end
	w.traces[S.n] = { hit = hit, ax = a.X, ay = a.Y, az = a.Z, bx = b.X, by = b.Y, bz = b.Z, channel = channel }
end

-- What the running work reads once (Measure.measure: the character's position, facing and capsule); a new table
-- outside a work.
function M.at()
	return S.current and S.current.at or {}
end

return M
