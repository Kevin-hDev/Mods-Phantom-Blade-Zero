-- Our own reading of the obstacle, in the shape of the game's traversal result. The game's choice of animation
-- (CHT_Hun_Traversal, read in the game's files) looks only at whether a back edge and a floor behind were found, then
-- at depth, height and back height; nothing in it caps the height. The cap near 2.6 m seen in game is therefore in
-- the game's detection, which this plan replaces when the game refuses.
-- Hurdle (1) when the obstacle is thin, with a floor behind at least HURDLE_DROP lower than its top, and no higher
-- than HURDLE_MAX; else mantle (3), up onto the top. The plan is refused, with the reason, when a point is missing:
-- the top of a face that leans back, the face's shape, a character or a moving object, a floor far down behind, a top
-- too thin, too steep or too narrow to stand on, an opening under the face (vault_room.lua). Low steps in front of
-- the obstacle are looked past. The drop behind a hurdle is limited by the player's settings, and a hurdle over a
-- floor deeper than the game's hurdles land ends in the air (LANDING).
-- A hurdle's targets are placed where the game places its own: with the back target on the real back edge, our
-- hurdles often ended standing on the obstacle or hanging from its edge, then fell, while the game's, back target
-- 110 cm from the front, all ended on the ground. The floor, and so the drop the player allows, is looked for where
-- the hurdle lands.

local Settings = require("vault_settings")
local Measure = require("vault_measure")
local Top = require("vault_top")
local Room = require("vault_room")
local Kind = require("vault_kind")

local P = {}

P.TOO_FAR = "too far"            -- the start of the reason when the obstacle is beyond MAX_REACH

local MAX_REACH = 200             -- cm: the game's DetectDistance
local HURDLE_DEPTH = 100          -- cm: the game's hurdles go up to 100 cm deep (CHT_Hun_Traversal)
local HURDLE_MAX = 250            -- cm: the game was seen hurdling up to 237 cm; above, a mantle
-- cm: a floor behind nearer the top than this is ground to walk on, not a drop; without it, a 200 cm obstacle whose
-- floor behind was level with its top was hurdled.
local HURDLE_DROP = 30
-- cm from the front where the game puts the back target of its hurdles, whatever their depth: 109 to 111 in 34
-- hurdles measured in game. Ours puts it there too, or past the real back
-- edge by the character's width when the obstacle is deeper, so that he lands clear of it.
local HURDLE_BACK = 110
-- cm past the back target where the game's hurdles land and their floor target is: 150 to 160 cm from the front.
local LANDING_PAST = 45
local FLOOR_DEPTH = 1000          -- cm below the top: the game's MaxFloorDepth
-- cm below the top: the game's hurdle animations land at most 200 cm below it (CHT_Hun_Traversal, BackHeight); deeper,
-- the game plays a mantle onto the top instead. A hurdle over a deeper floor lands this far below the top, in the
-- air, and the character falls from there.
local LANDING = 190
local NO_BACK_DEPTH = 55          -- cm: the depth the game gives an obstacle whose back it did not find
-- cm past the front a mantle needs free to stand up: a platform with a wall 94 cm back is still climbed.
local STAND = 60
local MIN_STAND = 25              -- cm of top a mantle needs: on less, the character would perch on an edge
local FLAT = 0.82                 -- a top whose normal's height is below this, steeper than about 35°, is not stood on
local MAX_STEPS = 3               -- low steps looked past in front of an obstacle

local function too_far(dist)
	return string.format("%s (%.0f cm)", P.TOO_FAR, dist)
end

-- The direction into the wall: against the front face's normal when it has one, else the way the character faces.
local function facing(scene)
	local n = scene.first.normal
	if n ~= nil then
		local flat = math.sqrt(n.x * n.x + n.y * n.y)
		if flat > 0.3 then return { x = -n.x / flat, y = -n.y / flat } end
	end
	return { x = scene.dx, y = scene.dy }
end

local function vec(p)
	return { x = p.X, y = p.Y, z = p.Z }
end

-- For a mantle, why the character cannot stand on the top, or nil. A top thinner than MIN_STAND holds him only when
-- the ground goes on behind it at its height; deep says why a hurdle over it was refused, when the drop behind was all.
local function unstandable(scene, front, dir, top, depth, level, deep)
	if depth ~= nil and depth < MIN_STAND and not level then
		return deep or "top too thin to stand on"
	end
	if top.normal ~= nil and top.normal.z < FLAT then return "top too steep to stand on" end
	return Room.narrow(scene, front, dir, top.z, top.probe)
end

-- The first face standing behind a top read from scene.first, on the plan's channel: above the top, further away,
-- and not ground to walk on; else nil.
local function behind(scene, top)
	for _, hit in ipairs(scene.face) do
		if scene.feet + hit.h > top.z and hit.dist > scene.first.dist and not Measure.ground(hit) then return hit end
	end
	return nil
end

-- The obstacle's top, looking past the steps in front of it: a step less than MinHeight over the one before (a low
-- step at a wall's foot was read as the obstacle, and the wall climbed only from right against it), or one too
-- shallow to stand on, a face rising behind it within STAND of its edge. What stands behind a low step must rise
-- MinHeight above it, so that stairs stay stairs. When the faces behind lead nowhere, the last step high enough is
-- kept. scene.first becomes the obstacle's foot; scene.read keeps the last top read, for the log. Else nil and why.
local function obstacle(scene)
	local base, low, kept = scene.feet, nil, nil
	for _ = 0, MAX_STEPS do
		local top, why = Top.find(scene)
		scene.read = top
		if top == nil then
			if kept == nil then return nil, why end
			break
		end
		local tall, further = top.z - base >= Settings.MinHeight, behind(scene, top)
		if tall and (further == nil or further.dist > top.edge + STAND) then return top end
		if tall then kept = { top = top, first = scene.first } else low = low or top.z - base end
		if further == nil then break end
		base, scene.first = top.z, further
	end
	if kept == nil then return nil, string.format("too low (%.0f cm)", low) end
	scene.first, scene.read = kept.first, kept.top
	return kept.top
end

-- The plan for this scene, or nil and why not.
function P.plan(scene)
	if scene == nil then return nil, "no measure" end
	if scene.first == nil then return nil, "nothing ahead" end
	if scene.first.dist > MAX_REACH then return nil, too_far(scene.first.dist) end
	if Room.opening(scene) then return nil, "an opening under the face" end
	local top, why = obstacle(scene)
	if top == nil then return nil, why end
	local first = scene.first
	if first.dist > MAX_REACH then return nil, too_far(first.dist) end
	local what = Kind.why_not(Measure.object(first)) or Kind.why_not(Measure.object(top.hit))
	if what then return nil, "the obstacle is " .. what end
	local height = top.z - scene.feet
	if height > Settings.MaxHeight then return nil, string.format("too high (%.0f cm)", height) end
	why = Top.wall(scene, top.z)
	if why then return nil, why end
	local dir = facing(scene)
	local front = { x = scene.loc.x + scene.dx * top.edge, y = scene.loc.y + scene.dy * top.edge, z = top.z }
	why = Room.blocked(scene, front, dir, top.z)
	if why then return nil, why end
	local depth, broke = Top.depth(scene, front, dir, top.z, top.probe)
	if broke then return nil, broke end
	-- The floor behind, where a hurdle lands (land_at from the front), looked for down past the deepest drop the player
	-- allows: drop, how far below the feet it is, math.huge when none was found (a void), nil without a back edge.
	local floor, drop, back_at, land_at = nil, nil, nil, nil
	if depth ~= nil then
		back_at = math.max(HURDLE_BACK, depth + 2 * scene.radius)
		land_at = back_at + LANDING_PAST
		local bottom = math.min(top.z - FLOOR_DEPTH, scene.feet - Settings.MaxDropBehind - 1)
		local f = Measure.trace(scene, Measure.along(front, dir, land_at, top.z), Measure.along(front, dir, land_at,
			bottom), scene.channel)
		if f == nil then return nil, "a trace call failed" end
		floor = f and f.z or nil
		drop = floor and scene.feet - floor or math.huge
	end
	local over = drop ~= nil and depth <= HURDLE_DEPTH and height <= HURDLE_MAX
		and (floor == nil or top.z - floor >= HURDLE_DROP)
	local hurdle = over and (not Settings.DropLimit or drop <= Settings.MaxDropBehind)
	local reach = top.edge + (hurdle and land_at or STAND)
	if Room.goes_on(scene, top.z, reach) then return nil, "the obstacle goes on above its top" end
	if not hurdle then
		local deep = over and (floor and string.format("drop behind too deep (%.0f cm)", drop)
			or "drop behind too deep (no floor found)")
		why = unstandable(scene, front, dir, top, depth, floor ~= nil and top.z - floor < HURDLE_DROP, deep)
		if why then return nil, why end
	end
	local land = hurdle and math.max(floor or -math.huge, top.z - LANDING) or nil
	-- A hurdle's depth is the game's for its own hurdles, which never let it pick the two animations it keeps for thin
	-- obstacles; edge, the real one, for the log.
	return {
		kind = hurdle and 1 or 3, eye = scene.eye_only, dir = dir, height = height,
		depth = not hurdle and depth or NO_BACK_DEPTH, edge = hurdle and depth or nil, front = front,
		back = depth and vec(Measure.along(front, dir, hurdle and back_at or depth, top.z)) or nil,
		floor = hurdle and vec(Measure.along(front, dir, land_at, land)) or nil,
		back_height = hurdle and top.z - land or 0,
		drop = hurdle and land ~= floor and drop or nil, -- set when the landing is in the air, above the floor
	}
end

-- How far the front still is, along the way in, from where the character stands now (cm; below 0: past it).
function P.ahead(plan, loc)
	return (plan.front.x - loc.x) * plan.dir.x + (plan.front.y - loc.y) * plan.dir.y
end

-- The plan as one text for the log; for a hurdle, back_edge=<the real depth, cm>, and drop=<cm below the feet, or
-- void> when it lands in the air.
function P.text(plan)
	local function at(p) return p and string.format("(%.0f,%.0f,%.0f)", p.x, p.y, p.z) or "none" end
	local edge, drop = plan.edge and string.format(" back_edge=%.0f", plan.edge) or "", ""
	if plan.drop then drop = plan.drop == math.huge and " drop=void" or string.format(" drop=%.0f", plan.drop) end
	return string.format("%s height=%.0f depth=%.0f%s back_height=%.0f front=%s back=%s floor=%s%s%s",
		plan.kind == 1 and "hurdle" or "mantle", plan.height, plan.depth, edge, plan.back_height, at(plan.front),
		at(plan.back), at(plan.floor), drop, plan.eye and " seen by the eye only" or "")
end

-- Where the plan read the obstacle, for the log after a refusal: " [face=<cm away>@<cm high> top=<cm high>@<front
-- edge, cm away> from=<cm high the traces down started at>]", with " eye" when read on the eye's channel; empty when
-- no top was read.
function P.detail(scene)
	local f, t = scene and scene.first, scene and scene.read
	if f == nil or t == nil then return "" end
	return string.format(" [face=%.0f@%d top=%.0f@%.0f from=%d%s]", f.dist, f.h, t.z - scene.feet, t.edge, t.from,
		scene.eye_only and " eye" or "")
end

return P
