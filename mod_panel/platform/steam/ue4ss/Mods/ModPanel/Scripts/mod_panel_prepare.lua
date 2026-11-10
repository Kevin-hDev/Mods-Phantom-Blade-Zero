-- The panel prepared while it is closed (D180): once the player has been in play for DELAY seconds since the last
-- load, an opening's steps (mod_panel_opening.lua) run one a frame, a slice of 3 ms at most, the panel hidden, until
-- the engine's functions are checked and the frame and the reserve are whole. The first opening after a load then
-- has nothing left to make. An opening that begins takes the work over; one shown leaves nothing to prepare until the
-- next load. A refusal stops the preparing until the next load: the opening still tries by itself.

local Game = require("mod_panel_game")

local M = {}

-- Seconds of play after a load before preparing. The game still loads the area in the first seconds: frames of
-- 60 to 150 ms in the first 3 s after a load with only our mods (10 November 2026), and a step slowed by the game
-- there made the slices crawl (D179).
M.DELAY = 10.0

-- opening: the panel's (mod_panel_opening.lua); enabled(): whether Mod Panel is on (off, nothing is prepared nor asked
-- of the game); report(fmt, ...), problem(fmt, ...): the panel's lines.
function M.new(opening, enabled, report, problem)
	-- state: "waiting" (for DELAY seconds of play), "preparing", "done" or "stopped" (until the next load). since:
	-- the clock when the player was last seen coming into play, nil while not in play. frames, longest: the
	-- preparing's frames and its longest.
	local R = { state = "waiting", since = nil, frames = 0, longest = 0 }

	function R.loaded()
		R.state, R.since, R.frames, R.longest = "waiting", nil, 0, 0
	end

	-- Whether the closed panel needs the frames' controller and its ticks.
	function R.wants()
		return (R.state == "waiting" or R.state == "preparing") and enabled()
	end

	function R.preparing()
		return R.state == "preparing" and enabled()
	end

	-- Ten times a second, the panel closed: out of play (a cutscene, a menu, the title screen), the wait starts again.
	function R.tick(pc, now)
		if not R.wants() then return end
		if not Game.in_play(pc) then
			R.since, R.state = nil, "waiting"
			return
		end
		R.since = R.since or now
		if R.state == "waiting" and now - R.since >= M.DELAY then
			R.state = "preparing"
			opening.begin()
		end
	end

	-- One step at a frame, the panel closed.
	function R.frame(pc)
		if not R.preparing() then return end
		local start = os.clock()
		local done, why, failed = opening.step(pc)
		R.frames, R.longest = R.frames + 1, math.max(R.longest, os.clock() - start)
		if done == nil then
			R.state = "stopped"
			local say = failed and problem or report
			say("panel: not prepared ahead (%s); the opening makes it", tostring(why))
		elseif done then
			R.state = "done"
			report("panel: prepared ahead in %d frames, the longest under %d ms", R.frames,
				math.floor(R.longest * 1000 + 0.5) + 1)
		end
	end

	-- An opening began: it goes on with what was prepared, and the preparing waits for the panel closed again.
	function R.opening()
		if R.wants() then R.state = "waiting" end
	end

	-- The panel was shown: everything is made.
	function R.made()
		R.state = "done"
	end

	return R
end

return M
