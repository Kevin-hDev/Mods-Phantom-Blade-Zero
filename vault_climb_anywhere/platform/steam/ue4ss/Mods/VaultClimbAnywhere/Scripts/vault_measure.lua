-- What stands in front of the character when the jump is pressed: horizontal traces at several heights above the
-- feet, up to 5 m. Each trace twice: on the visibility channel (what the eye sees) and on the channel the game's
-- vaulting looks with (MantleTrace), which ignores some obstacles, the boards of tall shelves among them. The plan
-- reads the vaulting's channel, and the eye's when the vaulting's sees nothing standing ahead (EyeObstacles,
-- vault_settings.lua). A hit on ground the character walks on, the slope he runs up, is not the obstacle; every hit is
-- kept with its height, for the face's shape (vault_top.lua).
-- A measure taken again in the air counts its heights from the feet at the press: from the feet of the moment,
-- already 0.6 to 2.2 m up, a 70 cm fence read as nothing ahead. What a hit touched is looked for only for the hits
-- that need it: most first hits come back unreadable, each read costing 8 to 25 us. The traces are the engine's
-- LineTraceSingle (KismetSystemLibrary.h, 5.7): they only read the world. The trace function is looked up once a
-- measure, and each trace goes through vault_spread.lua, which may spread a measure over frames; the character is
-- read once a measure.

local R = require("vault_reading")
local Settings = require("vault_settings")
local Classes = require("vault_classes")
local Spread = require("vault_spread")

local M = {}

local SYSTEM = "/Script/Engine.Default__KismetSystemLibrary"
local SYSTEM_CLASS = "/Script/Engine.KismetSystemLibrary"
M.VISIBILITY = 0                  -- ETraceTypeQuery::TraceTypeQuery1, the visibility channel
local NO_DRAW = 0                 -- EDrawDebugTrace::None
M.HEIGHTS = { 15, 30, 45, 60, 80, 100, 130, 160, 200, 250, 300, 350, 400, 450, 500 } -- cm above the feet
-- cm ahead: the face's foot is taken up to 2 m away (vault_plan.lua) and its top up to 1.5 m behind it
-- (vault_top.lua), so a face the mod can climb is met at every height it has.
local REACH = 360
M.BEYOND = 15                     -- cm past the front face, where the trace down falls
M.DROP_FROM = 550                 -- cm above the feet, where the trace down starts: above the highest height
M.DROP_TO = -20                   -- cm above the feet, where it ends
local HALF_HEIGHT = 90            -- cm, if the capsule cannot be read
-- cm, if the capsule cannot be read: the engine's default character's (ACharacter, 34 by 88); a trial build writes the
-- radius read in game when the character is ready.
local RADIUS = 34
local WALKABLE = 0.7              -- a hit whose normal's height is at least this (about 45° or flatter) is ground
local COLOR = { R = 0, G = 0, B = 0, A = 0 }

-- lib: the trace library, found once (it always exists: never a search for an absent object).
local S = { lib = nil }

local function find() return StaticFindObject(SYSTEM) end

function M.library()
	local class = Classes.get(SYSTEM_CLASS)
	if R.usable(S.lib, class) then return S.lib end
	local ok, lib = pcall(find)
	S.lib = ok and R.usable(lib, class) and lib or nil
	return S.lib
end

local function component_of(out) return out.Component:Get() end
local function reference_of(out) return out.HitObjectHandle.ReferenceObject:Get() end
local function actor_of(out) return out.HitObjectHandle.Actor:Get() end
local TOUCHED = { component_of, reference_of, actor_of }

-- What a hit touched, read in the frame of its trace: its component, else its actor through the hit's handle (the
-- engine example's reading for 5.4 and later; the component alone often reads empty). Returns it, or nil and, when
-- why is asked (a trial's line), the kinds of values found.
function M.object(hit, why)
	for _, get in ipairs(TOUCHED) do
		local ok, o = pcall(get, hit.out)
		if ok and R.is_valid(o) then return o, nil end
	end
	if not why then return nil, nil end
	return nil, string.format("unread: Component is %s, HitObjectHandle is %s", type(R.field(hit.out, "Component")),
		type(R.field(hit.out, "HitObjectHandle")))
end

local function line_trace(scene, a, b, channel, out)
	return scene.fn(scene.lib, scene.pawn, a, b, channel, false, {}, NO_DRAW, out, true, COLOR, COLOR, 0.0)
end

-- One trace from a to b, from the scene's character with its trace function: { dist, z, normal, out } when it hits
-- (M.object says what it touched), false when it does not, nil when the call failed.
local function traced(scene, a, b, channel)
	local out = {}
	local ok, hit = pcall(line_trace, scene, a, b, channel, out)
	if not ok then return nil end
	if hit ~= true then return false end
	return { dist = R.num(R.field(out, "Distance"), 0), z = R.num(R.field(R.field(out, "ImpactPoint"), "Z"), nil),
		normal = R.vec(R.field(out, "ImpactNormal")), out = out }
end

function M.trace(scene, a, b, channel)
	local kept = Spread.recall(a, b, channel)
	if kept ~= nil then return kept.hit end
	local hit = traced(scene, a, b, channel)
	Spread.keep(a, b, channel, hit)
	return hit
end

-- The character's position, facing and capsule, read once a measure: a measure spread over frames is taken from
-- where he stood at its first.
local function stance(pawn)
	local at = Spread.at()
	if not at.read then
		at.read = true
		at.loc = R.vec(R.read(function() return pawn:K2_GetActorLocation() end))
		at.fwd = R.vec(R.read(function() return pawn:GetActorForwardVector() end))
		at.half = R.num(R.read(function() return pawn.CapsuleComponent:GetScaledCapsuleHalfHeight() end), HALF_HEIGHT)
		at.radius = R.num(R.read(function() return pawn.CapsuleComponent:GetScaledCapsuleRadius() end), RADIUS)
	end
	return at
end

local function cm(v)
	if v == nil then return "?" end
	return v and string.format("%.0f", v) or "-"
end

-- The point ahead cm from loc along the facing (dx, dy), at height z; as the engine takes it.
function M.at(loc, dx, dy, ahead, z)
	return { X = loc.x + dx * ahead, Y = loc.y + dy * ahead, Z = z }
end

-- The point s cm from the front point along dir, at height z.
function M.along(front, dir, s, z)
	return { X = front.x + dir.x * s, Y = front.y + dir.y * s, Z = z }
end

-- Whether a hit is on ground the character walks on, the slope he runs up, rather than on something standing.
function M.ground(hit)
	return hit.normal ~= nil and hit.normal.z >= WALKABLE
end

local function lowest_standing(hits)
	for _, hit in ipairs(hits) do
		if not M.ground(hit) then return hit end
	end
	return nil
end

-- The measure as one text: the facing (degrees), then for each height the distance to what the visibility trace and
-- the vaulting's trace hit ("-": nothing within REACH); the top of the lowest obstacle above the feet, both ways; and
-- what it is. Second value, the scene for vault_plan.lua: nil when the measure could not be taken. Without with_text
-- (a published build), no text is built and the two traces down and the mesh read that only
-- the text uses are not made: the scene is the same. feet: the height of the feet at the press, for a measure taken
-- again; else the feet now.
function M.measure(pawn, channel, with_text, feet)
	local lib = M.library()
	if lib == nil then return "measure: no trace library", nil end
	local fn = R.field(lib, "LineTraceSingle")
	if fn == nil then return "measure: no trace function", nil end
	local at = stance(pawn)
	local loc, fwd, half, radius = at.loc, at.fwd, at.half, at.radius
	if loc == nil or fwd == nil then return "measure: position unreadable", nil end
	local flat = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
	if flat < 0.01 then return "measure: no facing", nil end
	local dx, dy = fwd.x / flat, fwd.y / flat
	feet = feet or loc.z - half
	local scene = { lib = lib, fn = fn, pawn = pawn, loc = loc, dx = dx, dy = dy, feet = feet, half = half,
		radius = radius, channel = channel }
	-- first: the lowest hit the eye sees, for the log. scene.ahead: every hit of the eye, with its height h, for
	-- vault_room.lua; scene.face: every hit of the channel the plan reads, with its height; scene.first: the lowest
	-- of those that is not ground, the obstacle's foot (vault_plan.lua).
	local parts, first = {}, nil
	scene.ahead, scene.face = {}, {}
	for _, h in ipairs(M.HEIGHTS) do
		local a, b = M.at(loc, dx, dy, 0, feet + h), M.at(loc, dx, dy, REACH, feet + h)
		local v, m = M.trace(scene, a, b, M.VISIBILITY), M.trace(scene, a, b, channel)
		if v == nil or m == nil then return "measure: the trace call failed", nil end
		if with_text then parts[#parts + 1] = string.format("%d:%s/%s", h, cm(v and v.dist), cm(m and m.dist)) end
		if v then
			v.h = h
			scene.ahead[#scene.ahead + 1] = v
			first = first or v
		end
		if m then
			m.h = h
			scene.face[#scene.face + 1] = m
		end
	end
	local seen = lowest_standing(scene.face)
	if seen == nil and Settings.EyeObstacles then
		seen = lowest_standing(scene.ahead)
		if seen ~= nil then scene.face, scene.channel, scene.eye_only = scene.ahead, M.VISIBILITY, true end
	end
	-- Only ground ahead: read from its lowest hit; the face check refuses it as not a wall.
	scene.first = seen or scene.face[1]
	if not with_text then return nil, scene end
	local text = string.format("measure (cm, eye/vaulting): facing=%.0f ahead %s", math.deg(math.atan(dy, dx)),
		table.concat(parts, " "))
	if first == nil then return text .. " top=none", scene end
	local a = M.at(loc, dx, dy, first.dist + M.BEYOND, feet + M.DROP_FROM)
	local b = M.at(loc, dx, dy, first.dist + M.BEYOND, feet + M.DROP_TO)
	local v, m = M.trace(scene, a, b, M.VISIBILITY), M.trace(scene, a, b, channel)
	local function top(t)
		if t == nil then return "?" end
		return t and t.z and string.format("%.0f", t.z - feet) or "-"
	end
	local comp, why = M.object(first, true)
	local mesh = R.read(function() return comp:GetStaticMesh() end)
	return string.format("%s top=%s/%s hit=%s mesh=%s", text, top(v), top(m), why or R.path(comp),
		R.is_valid(mesh) and R.short(R.path(mesh)) or "none"), scene
end

return M
