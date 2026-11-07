-- The mesh's place in the actor (its relative location and rotation), read and written for the tilt (slide_tilt.lua).
-- The untilted place, the base, is read when a tilt starts and written back when it is over. If the game moves the
-- mesh itself in between (crouching lowers it: ACharacter::OnStartCrouch writes its height), each part the game
-- changed becomes the base, so putting the base back never undoes the game's own move.

local R = require("slide_reading")
local Math = require("slide_tilt_math")

local M = {}

local TOL_LOC = 0.05              -- cm
local TOL_TURN = 1e-4             -- per matrix element
local HIT = {}                    -- the call's sweep result: no sweep, never read
local AXES = { "x", "y", "z" }

local function read(mesh)
	local t = nil
	pcall(function()
		local l, r = mesh.RelativeLocation, mesh.RelativeRotation
		t = { loc = { x = R.num(l.X, nil), y = R.num(l.Y, nil), z = R.num(l.Z, nil) },
			rot = { p = R.num(r.Pitch, nil), y = R.num(r.Yaw, nil), r = R.num(r.Roll, nil) } }
	end)
	if t == nil or t.loc.x == nil or t.loc.y == nil or t.loc.z == nil then return nil end
	if t.rot.p == nil or t.rot.y == nil or t.rot.r == nil then return nil end
	return t
end

-- The untilted place, { loc, rot, scale, m }, or nil when it cannot be read.
function M.base(mesh)
	local t = read(mesh)
	if t == nil then return nil end
	local s = nil
	pcall(function()
		local raw = mesh.RelativeScale3D
		s = { x = R.num(raw.X, 1), y = R.num(raw.Y, 1), z = R.num(raw.Z, 1) }
	end)
	t.scale = s or { x = 1, y = 1, z = 1 }
	t.m = Math.matrix(t.rot)
	return t
end

-- Returns true when written. Teleport: the move is a pose, not a motion to simulate.
function M.write(mesh, loc, rot)
	return pcall(function()
		mesh:K2_SetRelativeLocationAndRotation({ X = loc.x, Y = loc.y, Z = loc.z },
			{ Pitch = rot.p, Yaw = rot.y, Roll = rot.r }, false, HIT, true)
	end)
end

function M.same(a, b)
	return math.abs(a.loc.x - b.loc.x) <= TOL_LOC and math.abs(a.loc.y - b.loc.y) <= TOL_LOC
		and math.abs(a.loc.z - b.loc.z) <= TOL_LOC and Math.same_turn(a.rot, b.rot, TOL_TURN)
end

-- What the game changed since our last write (last = { loc, rot }) goes into base. Returns the mesh's place now when
-- the game changed something, else nil.
function M.adopt(mesh, base, last)
	local t = read(mesh)
	if t == nil then return nil end
	local changed = false
	for _, c in ipairs(AXES) do
		if math.abs(t.loc[c] - last.loc[c]) > TOL_LOC then base.loc[c], changed = t.loc[c], true end
	end
	if not Math.same_turn(t.rot, last.rot, TOL_TURN) then
		base.rot, base.m, changed = t.rot, Math.matrix(t.rot), true
	end
	return changed and t or nil
end

return M
