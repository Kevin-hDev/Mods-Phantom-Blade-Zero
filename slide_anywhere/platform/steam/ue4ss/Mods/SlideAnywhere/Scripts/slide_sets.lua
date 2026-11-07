-- The slide's animation: the 45° slope slide, the only one in memory (second trial, 4 November 2026), kept by Kevin
-- ("déjà pas mal", 5 November 2026). Two others found in the game's files are dropped: the old floor slide (slope_A)
-- looked the same in game (fifth version), and the sand slide is never in memory, while loading it ourselves
-- (LoadAsset, from the controller's tick) froze the game both times it was tried (4 November 2026 at 23:37,
-- 5 November at 00:19).

local R = require("slide_reading")

local M = {}

local SLOPE = "/PBZCombatAsset/ActorData/Players/Hun/Montage/SpecialMove/Sliding/"
	.. "Museum_AnimationSequence_Traversal_Slide_45Degree_Slope_"

-- "/A/B/Name" gives "/A/B/Name.Name", the object inside the package.
local function montage(name, rate)
	local path = SLOPE .. name
	return { path = path .. "." .. path:match("([^/]+)$"), rate = rate }
end

M.SLIDE = { start = montage("LoopStart_Montage", 1.5), loop = montage("Loop_Montage", 1.5) }

local L = { said = {} }

-- The animation in memory; nil when it is not, said once per path.
function M.load(say, entry)
	local obj = nil
	pcall(function() obj = StaticFindObject(entry.path) end)
	if R.is_valid(obj) then return obj end
	if not L.said[entry.path] then
		L.said[entry.path] = true
		say("not in memory, no slide: %s (said once)", entry.path)
	end
	return nil
end

return M
