-- The values Dynamic FOV reads and writes in a camera's image settings (FPostProcessSettings, Unreal 5.7 Scene.h): each
-- value has its override flag, bOverride_<name>, and counts only while that flag is set. Written in place, as the
-- struct sits in the camera (ImageProbe, 5 November 2026: every write held in place); a struct UE4SS would give as a
-- copy is written whole instead.

local U = require("dynamic_fov_unreal")

local M = {}

-- The general saturation: the engine multiplies each range's by it (PostProcessCombineLUTs.usf, lines 111 to 129).
-- The camera's value replaces the places' own, which set it at 1.00 or 1.05 in the first zone while they set the
-- ranges further away (shadows 1.25): written here, the ranges stay the places' (ImageProbe, 5 November 2026).
M.SATURATION = "ColorSaturation"
M.EFFECTS = { "VignetteIntensity", "FilmGrainIntensity", "BloomIntensity", "SceneFringeIntensity", "LensFlareIntensity" }
M.NEUTRAL = { X = 1, Y = 1, Z = 1, W = 1 }

local SAME = 1e-3
local AXES = { "X", "Y", "Z", "W" }

local function vector(v)
	local ok, x, y, z, w = pcall(function() return v.X, v.Y, v.Z, v.W end)
	if not ok then return nil end
	x, y, z, w = U.num(x), U.num(y), U.num(z), U.num(w)
	if x == nil or y == nil or z == nil or w == nil then return nil end
	return { X = x, Y = y, Z = z, W = w }
end

-- One value: { on = its override flag, value = a number or { X, Y, Z, W } }, or nil when it cannot be read.
function M.read(pp, field)
	local okf, on = pcall(function() return pp["bOverride_" .. field] end)
	local okv, v = pcall(function() return pp[field] end)
	if not okf or not okv or v == nil then return nil end
	local value = type(v) == "number" and U.num(v) or vector(v)
	if value == nil then return nil end
	return { on = on == true, value = value }
end

local function same(a, b)
	if type(a) == "number" or type(b) == "number" then
		return type(a) == type(b) and math.abs(a - b) < SAME
	end
	for _, k in ipairs(AXES) do
		if math.abs(a[k] - b[k]) >= SAME then return false end
	end
	return true
end

-- Whether the entry read holds value with its flag set, or, flag given, with that flag.
function M.holds(entry, value, flag)
	if entry == nil then return false end
	if flag == nil then flag = true end
	return entry.on == flag and same(entry.value, value)
end

local function put(pp, field, value)
	if type(value) == "number" then
		pcall(function() pp[field] = value end)
	else
		pcall(function()
			local v = pp[field]
			v.X, v.Y, v.Z, v.W = value.X, value.Y, value.Z, value.W
		end)
		local e = M.read(pp, field)
		if e == nil or not same(e.value, value) then
			pcall(function() pp[field] = { X = value.X, Y = value.Y, Z = value.Z, W = value.W } end)
		end
	end
	local e = M.read(pp, field)
	return e ~= nil and same(e.value, value)
end

-- Sets the value, then its flag: the flag never turns on over an old value. Returns whether both held.
function M.write(pp, field, value)
	if not put(pp, field, value) then return false end
	return (pcall(function() pp["bOverride_" .. field] = true end))
end

-- Gives back an entry read before the first write: its value, then its flag.
function M.restore(pp, field, saved)
	if not put(pp, field, saved.value) then return false end
	return (pcall(function() pp["bOverride_" .. field] = saved.on end))
end

return M
