-- Reads what the mod needs as plain numbers and strings. Every read is wrapped: one unreadable field must not stop
-- the others. The reads made each frame go through named functions that take the object as a parameter, so that a
-- frame creates no new Lua function for them.

local M = {}

local function index(obj, key) return obj[key] end
local function call_is_valid(obj) return obj:IsValid() end
local function call_is_a(obj, class) return obj:IsA(class) end
local function call_address(obj) return obj:GetAddress() end
local function call_get(p) return p:get() end

function M.num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v then return default end
	return v
end

function M.read(fn)
	local ok, v = pcall(fn)
	if ok then return v end
	return nil
end

-- obj[key], or nil when obj is nil or the field cannot be read.
function M.field(obj, key)
	if obj == nil then return nil end
	local ok, v = pcall(index, obj, key)
	if ok then return v end
	return nil
end

-- A value for the log: whole numbers without decimals, others with two.
function M.text(v)
	if type(v) == "number" then
		if v == math.floor(v) then return string.format("%d", v) end
		return string.format("%.2f", v)
	end
	return tostring(v)
end

function M.is_valid(obj)
	if obj == nil then return false end
	local ok, valid = pcall(call_is_valid, obj)
	return ok and valid == true
end

-- Whether obj is a live object of class: the class itself (vault_classes.lua), or its full path, which UE4SS looks up
-- at each call. IsValid only says that a live object sits at the kept address: once the game frees an object, another
-- can take its address.
function M.usable(obj, class)
	if not M.is_valid(obj) then return false end
	local ok, yes = pcall(call_is_a, obj, class)
	return ok and yes == true
end

-- UE4SS's GetClass has no null check: on an unset property it crashes past any pcall, so check first.
function M.class_name(obj)
	if not M.is_valid(obj) then return "none" end
	local ok, n = pcall(function() return obj:GetClass():GetFName():ToString() end)
	return ok and n or "?"
end

function M.full_name(obj)
	if not M.is_valid(obj) then return "none" end
	local ok, n = pcall(function() return obj:GetFullName() end)
	return ok and type(n) == "string" and n or "?"
end

function M.path(obj)
	local full = M.full_name(obj)
	return full:match("^%S+%s+(.+)$") or full
end

-- The last part of an asset path: "/A/B/Name.Name" gives "Name".
function M.short(path)
	if path == nil then return nil end
	return path:match("([^/.:]+)$") or path
end

function M.address(obj)
	if obj == nil then return nil end
	local ok, a = pcall(call_address, obj)
	return ok and a or nil
end

function M.unwrap(p)
	if p == nil then return nil end
	local ok, v = pcall(call_get, p)
	if ok then return v end
	return p
end

-- A vector as { x, y, z }, or nil.
function M.vec(raw)
	if raw == nil then return nil end
	local v = nil
	pcall(function() v = { x = M.num(raw.X, 0), y = M.num(raw.Y, 0), z = M.num(raw.Z, 0) } end)
	return v
end

function M.vec_text(v)
	if v == nil then return "na" end
	return string.format("(%.0f,%.0f,%.0f)", v.x, v.y, v.z)
end

-- The player's position, flat speed and movement mode (1 walking, 3 falling, 5 flying), as one text.
function M.where(pawn)
	local pos, speed, mode = nil, nil, nil
	pcall(function() pos = M.vec(pawn:K2_GetActorLocation()) end)
	pcall(function()
		local v = M.vec(pawn.CharacterMovement.Velocity)
		speed = math.sqrt(v.x * v.x + v.y * v.y)
	end)
	pcall(function() mode = M.num(pawn.CharacterMovement.MovementMode, nil) end)
	return string.format("at %s speed=%s mode=%s", M.vec_text(pos), speed and string.format("%.0f", speed) or "na",
		mode and string.format("%d", mode) or "na")
end

return M
