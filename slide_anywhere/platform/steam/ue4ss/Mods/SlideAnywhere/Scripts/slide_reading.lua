-- Reads what the slide needs as plain numbers and strings. Every read is wrapped: one unreadable field must not stop
-- the others. Taken from SlideProbe's slide_reading.lua (each UE4SS mod loads only its own scripts).

local M = {}

function M.num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v then return default end
	return v
end

function M.is_valid(obj)
	if obj == nil then return false end
	local ok, valid = pcall(function() return obj:IsValid() end)
	return ok and valid == true
end

-- Whether obj is a live object of class (its full path, "/Script/Engine.AnimMontage"), for an object kept from one
-- frame to the next and handed to the game. IsValid only says that a live object sits at the kept address: once the
-- game unloads an object, another can take its address, and an object of another class handed to the game is a
-- native crash that pcall cannot catch (Dodge Jump's crash audit, 4 November 2026; same check as its objects module).
function M.usable(obj, class)
	if not M.is_valid(obj) then return false end
	local ok, yes = pcall(function() return obj:IsA(class) end)
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
	local ok, a = pcall(function() return obj:GetAddress() end)
	return ok and a or nil
end

function M.unwrap(p)
	if p == nil then return nil end
	local ok, v = pcall(function() return p:get() end)
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

-- The player's movement, once per frame: movement mode (1 walking, 3 falling, 5 flying), position, velocity and its
-- flat size, facing (yaw in degrees), and the movement component (cmc) for those who read or write it this frame.
function M.state(pawn)
	local s, cmc, vel = {}, nil, nil
	pcall(function() cmc = pawn.CharacterMovement end)
	s.cmc = cmc
	pcall(function() s.mode = M.num(cmc.MovementMode, nil) end)
	pcall(function() vel = M.vec(cmc.Velocity) end)
	if vel ~= nil then
		s.vx, s.vy, s.vz = vel.x, vel.y, vel.z
		s.speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
	end
	pcall(function() s.pos = M.vec(pawn:K2_GetActorLocation()) end)
	pcall(function() s.yaw = M.num(pawn:K2_GetActorRotation().Yaw, nil) end)
	return s
end

-- The movement mode alone (as in M.state), for a frame that needs nothing else: in the air, waiting for the landing.
function M.mode(pawn)
	local m = nil
	pcall(function() m = M.num(pawn.CharacterMovement.MovementMode, nil) end)
	return m
end

function M.f(v, fmt)
	if v == nil then return "na" end
	return string.format(fmt or "%.0f", v)
end

return M
