-- Rotations the way Unreal writes them, for the tilt (slide_tilt.lua). A rotator is { p, y, r } in degrees (Pitch,
-- Yaw, Roll); its matrix holds, row by row, where the turned X, Y and Z axes point (FRotationMatrix and
-- FMatrix::Rotator, UE 5.7 source). A vector v turned by a matrix m is v.x * row 1 + v.y * row 2 + v.z * row 3,
-- and mul(a, b) turns by a, then by b: a mesh turned by its own rotation inside the actor, then tilted in the
-- actor's space, is mul(own, tilt).

local M = {}

function M.matrix(r)
	local p, y, ro = math.rad(r.p), math.rad(r.y), math.rad(r.r)
	local sp, cp, sy, cy, sr, cr = math.sin(p), math.cos(p), math.sin(y), math.cos(y), math.sin(ro), math.cos(ro)
	return {
		{ cp * cy, cp * sy, sp },
		{ sr * sp * cy - cr * sy, sr * sp * sy + cr * cy, -sr * cp },
		{ -(cr * sp * cy + sr * sy), cy * sr - cr * sp * sy, cr * cp },
	}
end

function M.apply(v, m)
	return {
		x = v.x * m[1][1] + v.y * m[2][1] + v.z * m[3][1],
		y = v.x * m[1][2] + v.y * m[2][2] + v.z * m[3][2],
		z = v.x * m[1][3] + v.y * m[2][3] + v.z * m[3][3],
	}
end

function M.mul(a, b)
	local out = {}
	for i = 1, 3 do
		local t = M.apply({ x = a[i][1], y = a[i][2], z = a[i][3] }, b)
		out[i] = { t.x, t.y, t.z }
	end
	return out
end

function M.rotator(m)
	local x, y, z = m[1], m[2], m[3]
	local pitch = math.deg(math.atan(x[3], math.sqrt(x[1] * x[1] + x[2] * x[2])))
	local yaw = math.deg(math.atan(x[2], x[1]))
	local sy = M.matrix({ p = pitch, y = yaw, r = 0 })[2]
	local roll = math.deg(math.atan(z[1] * sy[1] + z[2] * sy[2] + z[3] * sy[3],
		y[1] * sy[1] + y[2] * sy[2] + y[3] * sy[3]))
	return { p = pitch, y = yaw, r = roll }
end

-- Two rotations are the same turn when their matrices match, whatever numbers name them (Unreal may write back
-- another rotator for the same turn).
function M.same_turn(a, b, tolerance)
	local ma, mb = M.matrix(a), M.matrix(b)
	for i = 1, 3 do
		for j = 1, 3 do
			if math.abs(ma[i][j] - mb[i][j]) > tolerance then return false end
		end
	end
	return true
end

function M.add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end
function M.sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
function M.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

-- k of the way from a to b.
function M.toward(a, b, k)
	return { x = a.x + (b.x - a.x) * k, y = a.y + (b.y - a.y) * k, z = a.z + (b.z - a.z) * k }
end

function M.unit(v)
	local len = math.sqrt(M.dot(v, v))
	return { x = v.x / len, y = v.y / len, z = v.z / len }
end

-- A world direction in the space of an actor turned by yaw degrees (our slide keeps its pitch and roll at zero).
function M.to_actor(v, yaw)
	local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	return { x = v.x * c + v.y * s, y = -v.x * s + v.y * c, z = v.z }
end

-- The pitch, from 0 to most degrees, that brings the lifted foot down to want cm above the planted one, measured
-- along the floor's normal n: the body leans back about the actor's side axis through the planted foot. d is the
-- lifted foot minus the planted one, in the actor's space. 0 when leaning back would not lower it (a foot ahead).
-- lift is apply(d, matrix({ p = deg, y = 0, r = 0 })) then dot with n, written out: it runs 33 times a frame, and
-- with the whole matrix and its tables solve took 31 microseconds instead of 4.5 (audit of 0.5.2, measured outside the
-- game). The test checks both give the same numbers.
function M.solve(d, n, want, most)
	local function lift(deg)
		local r = math.rad(deg)
		local sp, cp = math.sin(r), math.cos(r)
		return (d.x * cp - d.z * sp) * n.x + d.y * n.y + (d.x * sp + d.z * cp) * n.z
	end
	local start = lift(0)
	if start <= want or lift(0.5) >= start then return 0 end
	if lift(most) >= want then return most end
	local lo, hi = 0, most
	for _ = 1, 30 do
		local mid = (lo + hi) / 2
		if lift(mid) > want then lo = mid else hi = mid end
	end
	return (lo + hi) / 2
end

return M
