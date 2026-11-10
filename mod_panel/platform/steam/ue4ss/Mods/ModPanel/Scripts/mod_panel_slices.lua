-- Work cut in slices, so that no frame does more of it than a budget (optimisation.md, 7.1; D38): a step at least,
-- then the next one only while it would still fit, its cost guessed from the longest step of the last WINDOW slices.
-- The reading of the mods, the frame's build and the reserve's all go through here.
--
-- Not the longest step ever seen (D179): the clock is the wall's, and a step the game slowed once (a hitch while it
-- loads, after a save is loaded) left every later slice one step, the reserve's thousand steps a frame each: first
-- openings of 900 to 991 frames instead of 40 (trials of 8 and 10 November 2026, D174).

local M = {}

local WINDOW = 8                  -- slices a step's cost is remembered for

-- step() does the next step and returns true once no step is left. s keeps the longest step of each recent slice from
-- one slice to the next ({} to begin with). Returns whether all is done.
function M.run(step, budget, s)
	s.recent = s.recent or {}
	local guess = 0
	for i = 1, WINDOW do guess = math.max(guess, s.recent[i] or 0) end
	local start, longest, done = os.clock(), 0, false
	repeat
		local before = os.clock()
		done = step()
		longest = math.max(longest, os.clock() - before)
		guess = math.max(guess, longest)
	until done or os.clock() - start + guess > budget
	s.at = (s.at or 0) % WINDOW + 1
	s.recent[s.at] = longest
	return done
end

return M
