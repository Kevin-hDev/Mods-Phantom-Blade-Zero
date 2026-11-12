-- The cameras that hold the mod's image (dynamic_fov_image.lua): each one's own values, kept at its first write and
-- given back when the setting goes back to the game's, the mod is off, or its place is needed. A camera is held from
-- the first look that sees through it, or, a camera actor's, from the frame the game makes it (1.0.8).

local U = require("dynamic_fov_unreal")
local V = require("dynamic_fov_image_values")

local M = {}

local MAX_CAMERAS = 16            -- the player's and a few scenes' between two loads; a bound all the same

-- records[address]: a camera written to, { cam, name, saved = { field = entry }, written = { field = true }, order,
-- early }; order: the higher the later held; early: held from its making, and not seen through at a look since.
local H = { records = {}, count = 0, order = 0, full_said = false, unread_said = false }

local function full_name(obj)
	local ok, n = pcall(function() return obj:GetFullName() end)
	return ok and type(n) == "string" and n or nil
end

local function settings_of(cam)
	local ok, pp = pcall(function() return cam.PostProcessSettings end)
	return ok and pp or nil
end

-- The camera's short name, for a line.
function M.name(rec)
	local ok, n = pcall(function() return rec.cam:GetFName():ToString() end)
	return ok and type(n) == "string" and n or "?"
end

function M.count()
	return H.count
end

-- address, record of each camera held; one may be let go on the way.
function M.each()
	return pairs(H.records)
end

function M.drop(addr)
	H.records[addr], H.count = nil, H.count - 1
	if H.count == 0 then H.full_said = false end
end

-- A camera gone (a scene's, or a load's) holds nothing to give back; an address taken by another object is never
-- written. A name that cannot be read now is no other object: dropping the camera there would keep its next values,
-- the mod's own, as the camera's (audit of 6 November 2026). The name is read only on a camera that still exists: on
-- a destroyed one the read crashes the game, and no pcall catches it (crash of 6 November 2026).
local function gone(rec)
	if not U.is_valid(rec.cam) then return true end
	local name = full_name(rec.cam)
	return name ~= nil and name ~= rec.name
end

-- Lets go of every camera gone.
function M.prune()
	for addr, rec in pairs(H.records) do
		if gone(rec) then M.drop(addr) end
	end
end

-- Brings one camera to targets, { field = value }: a field written and no longer in them gets the camera's own value
-- back. Returns the values written and those that could not be.
function M.apply(rec, targets)
	local pp = settings_of(rec.cam)
	if pp == nil then return 0, 1 end
	local writes, failed = 0, 0
	for field in pairs(rec.written) do
		if targets[field] == nil then
			local saved = rec.saved[field]
			if V.holds(V.read(pp, field), saved.value, saved.on) or V.restore(pp, field, saved) then
				rec.written[field], writes = nil, writes + 1
			else
				failed = failed + 1
			end
		end
	end
	for field, value in pairs(targets) do
		if not V.holds(V.read(pp, field), value) then
			if V.write(pp, field, value) then writes = writes + 1 else failed = failed + 1 end
			rec.written[field] = true
		end
	end
	return writes, failed
end

-- Every place taken: the camera held longest from its making without being seen through gets its own values back and
-- is let go. A camera of the level that lives on never keeps the place of a scene's, nor of the one seen through.
local function make_room()
	local oldest, at = nil, nil
	for addr, rec in pairs(H.records) do
		if rec.early and (oldest == nil or rec.order < oldest.order) then oldest, at = rec, addr end
	end
	if oldest == nil then return false end
	if not gone(oldest) and select(2, M.apply(oldest, {})) > 0 then return false end
	M.drop(at)
	return true
end

-- The record of cam, kept from now when it is not held yet, or nil; then whether its image settings cannot be read
-- at all. early: the game just made it. problem(fmt, ...) hears of what went wrong, once each.
function M.take(cam, problem, early)
	local addr = U.address(cam)
	if addr == nil then return nil, false end
	-- A camera just made is not held yet: a record at its address is a camera gone since the last look.
	if early and H.records[addr] ~= nil then M.drop(addr) end
	local rec = H.records[addr]
	if rec ~= nil then
		rec.early = nil
		return rec, false
	end
	if H.count >= MAX_CAMERAS and not make_room() then
		if not H.full_said then
			H.full_said = true
			problem("image: %d cameras already hold the mod's image; a new one keeps the game's", MAX_CAMERAS)
		end
		return nil, false
	end
	local pp = settings_of(cam)
	H.order = H.order + 1
	rec = { cam = cam, name = full_name(cam), saved = {}, written = {}, order = H.order, early = early or nil }
	local unread = 0
	for _, f in ipairs({ V.SATURATION, table.unpack(V.EFFECTS) }) do
		rec.saved[f] = pp and V.read(pp, f)
		if rec.saved[f] == nil then unread = unread + 1 end
	end
	-- Said once: a game update that renamed a field would otherwise leave the player without colours, and no word.
	if unread > 0 and not H.unread_said then
		H.unread_said = true
		problem("image: %d of the 6 image settings of %s cannot be read; they keep the game's", unread, M.name(rec))
	end
	if unread == 1 + #V.EFFECTS then return nil, true end
	H.records[addr], H.count = rec, H.count + 1
	return rec, false
end

return M
