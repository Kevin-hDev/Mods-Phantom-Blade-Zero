-- The colours and the clean image (1.0.3), the only part of the mod that writes a camera's image settings. The engine
-- views through the view target's first active camera component (Unreal 5.7, AActor::CalcCamera), whose settings come
-- after the places' own: there the general saturation is the camera's own times the profile (it replaces the places'
-- general one, their ranges stay theirs), and the five effects set at 0 (dynamic_fov_image_values.lua). In play that camera is a cinema camera on the player's character; in a cutscene, the
-- cutscene's own. Each camera's own values are kept at the first write and given back when the setting goes back to
-- the game's, or the mod is off. Looked at once a second (a value the game put back is written again) and at once
-- after a change. Nothing is asked of the game while the colours are the game's and the image is not cleaned.

local U = require("dynamic_fov_unreal")
local V = require("dynamic_fov_image_values")

local M = {}

local CAMERA_CLASS = "/Script/Engine.CameraComponent"
local MAX_CAMERAS = 16            -- the player's and a few cutscenes' between two loads; a bound all the same

-- want: { factor = number or nil, clean = boolean }, nil for the game's image. records[address]: a camera written to,
-- { cam, name, saved = { field = entry }, written = { field = true } }; at most MAX_CAMERAS.
local I = { want = nil, records = {}, count = 0, class = nil, dirty = false, full_said = false, unread_said = false }

local function full_name(obj)
	local ok, n = pcall(function() return obj:GetFullName() end)
	return ok and type(n) == "string" and n or nil
end

local function short_name(obj)
	local ok, n = pcall(function() return obj:GetFName():ToString() end)
	return ok and type(n) == "string" and n or "?"
end

local function view_camera(pc)
	if not U.is_valid(I.class) then
		local ok, c = pcall(StaticFindObject, CAMERA_CLASS)
		I.class = ok and c or nil
		if not U.is_valid(I.class) then return nil end
	end
	local ok, cam = pcall(function() return pc.PlayerCameraManager.ViewTarget.Target:GetComponentByClass(I.class) end)
	return ok and U.is_valid(cam) and cam or nil
end

local function settings_of(cam)
	local ok, pp = pcall(function() return cam.PostProcessSettings end)
	return ok and pp or nil
end

-- The colours' factor (nil: the game's) and whether the image is cleaned; the mod off gives (nil, false).
function M.want(factor, clean)
	local w = (factor ~= nil or clean) and { factor = factor, clean = clean == true } or nil
	local before = I.want
	if (w == nil) ~= (before == nil) or (w and (w.factor ~= before.factor or w.clean ~= before.clean)) then
		I.want, I.dirty = w, true
	end
end

-- Whether a change waits for the next look.
function M.pending()
	return I.dirty
end

-- The values the camera of rec gets now, by field.
local function targets(rec)
	local t = {}
	if I.want == nil then return t end
	local own = rec.saved[V.SATURATION]
	if I.want.factor ~= nil and own ~= nil then
		local base = own.on and own.value or V.NEUTRAL
		t[V.SATURATION] = { X = base.X, Y = base.Y, Z = base.Z, W = base.W * I.want.factor }
	end
	if I.want.clean then
		for _, f in ipairs(V.EFFECTS) do
			if rec.saved[f] ~= nil then t[f] = 0 end
		end
	end
	return t
end

-- A camera is kept from its first look; returns false when its image settings cannot be read at all.
local function record(cam, problem)
	local addr = U.address(cam)
	if addr == nil then return true end
	local rec = I.records[addr]
	if rec ~= nil then return true end
	if I.count >= MAX_CAMERAS then
		if not I.full_said then
			I.full_said = true
			problem("image: %d cameras already hold the mod's image; a new one keeps the game's", MAX_CAMERAS)
		end
		return true
	end
	local pp = settings_of(cam)
	rec = { cam = cam, name = full_name(cam), saved = {}, written = {} }
	local unread = 0
	for _, f in ipairs({ V.SATURATION, table.unpack(V.EFFECTS) }) do
		rec.saved[f] = pp and V.read(pp, f)
		if rec.saved[f] == nil then unread = unread + 1 end
	end
	-- Said once: a game update that renamed a field would otherwise leave the player without colours, and no word.
	if unread > 0 and not I.unread_said then
		I.unread_said = true
		problem("image: %d of the 6 image settings of %s cannot be read; they keep the game's", unread, short_name(cam))
	end
	if unread == 1 + #V.EFFECTS then return false end
	I.records[addr], I.count = rec, I.count + 1
	return true
end

-- Brings one camera to what is wanted; returns the values written and those that could not be.
local function apply(rec)
	local pp = settings_of(rec.cam)
	if pp == nil then return 0, 1 end
	local writes, failed = 0, 0
	local t = targets(rec)
	for field in pairs(rec.written) do
		if t[field] == nil then
			local saved = rec.saved[field]
			if V.holds(V.read(pp, field), saved.value, saved.on) or V.restore(pp, field, saved) then
				rec.written[field], writes = nil, writes + 1
			else
				failed = failed + 1
			end
		end
	end
	for field, value in pairs(t) do
		if not V.holds(V.read(pp, field), value) then
			if V.write(pp, field, value) then writes = writes + 1 else failed = failed + 1 end
			rec.written[field] = true
		end
	end
	return writes, failed
end

-- Once a second, and at the tick after a change. pc: the player controller. report(fmt, ...) hears of each camera
-- brought to a new image, problem(fmt, ...) of what went wrong: values refused, settings unreadable, too many cameras.
-- Returns the values written and those that could not be.
function M.look(pc, report, problem)
	problem = problem or report
	I.dirty = false
	if I.want == nil and I.count == 0 then return 0, 0 end
	for addr, rec in pairs(I.records) do
		-- A camera gone (a cutscene's, or a load's) holds nothing to give back; an address taken by another object
		-- is never written. A name that cannot be read now is no other object: dropping the camera there would keep its
		-- next values, the mod's own, as the camera's (audit of 6 November 2026). The name is read only on a camera that
		-- still exists: on a destroyed one the read crashes the game, and no pcall catches it (crash of 6 November 2026).
		local gone = not U.is_valid(rec.cam)
		if not gone then
			local name = full_name(rec.cam)
			gone = name ~= nil and name ~= rec.name
		end
		if gone then
			I.records[addr], I.count = nil, I.count - 1
		end
	end
	local writes, failed = 0, 0
	if I.want ~= nil then
		local cam = view_camera(pc)
		if cam ~= nil and not record(cam, problem) then failed = failed + 1 end
	end
	for addr, rec in pairs(I.records) do
		local w, f = apply(rec)
		writes, failed = writes + w, failed + f
		if w > 0 or f > 0 then
			(f > 0 and problem or report)("image: %s (%s, %d written%s)", I.want == nil and "the game's back"
				or string.format("colours %s, clean image %s", I.want.factor and string.format("x%.1f", I.want.factor)
					or "the game's", I.want.clean and "on" or "off"), short_name(rec.cam), w,
				f > 0 and string.format(", %d could not be", f) or "")
		end
		if I.want == nil and next(rec.written) == nil then I.records[addr], I.count = nil, I.count - 1 end
	end
	if I.count == 0 then I.full_said = false end
	return writes, failed
end

return M
