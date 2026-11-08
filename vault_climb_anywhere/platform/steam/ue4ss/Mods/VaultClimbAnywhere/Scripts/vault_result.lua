-- The game's traversal result as one text, for a trial build's lines: the action (0 none, 1 hurdle, 2 vault,
-- 3 mantle), the front, back and floor targets, the heights and depth, what was hit and the animation chosen.

local R = require("vault_reading")

local M = {}

local ACTIONS = { [0] = "none", "hurdle", "vault", "mantle" }

function M.text(comp)
	local r = R.read(function() return comp.TraversalResult end)
	if r == nil then return "result unreadable" end
	local function get(k) return R.read(function() return r[k] end) end
	local function at(k) return R.vec_text(R.vec(R.read(function() return r[k].Translation end))) end
	local a = R.num(get("ActionType"), -1)
	return string.format("action=%s front=%s%s back=%s%s floor=%s%s height=%s depth=%s back_height=%s hit=%s "
		.. "montage=%s start=%s rate=%s", ACTIONS[a] or R.text(a), R.text(get("bHasFrontTarget")), at("FrontTarget"),
		R.text(get("bHasBackTarget")), at("BackTarget"), R.text(get("bHasFloorTarget")), at("FloorTarget"),
		R.text(get("ObstacleHeight")), R.text(get("ObstacleDepth")), R.text(get("BackHeight")),
		R.path(get("HitComponent")), R.short(R.path(get("ChosenMontage"))), R.text(get("StartTime")),
		R.text(get("PlayRate")))
end

return M
