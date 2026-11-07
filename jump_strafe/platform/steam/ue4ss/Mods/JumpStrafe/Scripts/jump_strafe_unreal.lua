-- Safe access to game objects through UE4SS: every call is wrapped, an unreadable value comes back as nil.

local M = {}

function M.num(v)
	v = tonumber(v)
	if v == nil or v ~= v then return nil end
	return v
end

function M.is_valid(obj)
	if obj == nil then return false end
	local ok, valid = pcall(function() return obj:IsValid() end)
	return ok and valid == true
end

function M.address(obj)
	local ok, a = pcall(function() return obj:GetAddress() end)
	return ok and a or nil
end

-- Hook parameters arrive wrapped; plain values pass through.
function M.unwrap(p)
	if p == nil then return nil end
	local ok, v = pcall(function() return p:get() end)
	if ok then return v end
	return p
end

function M.read(obj, field)
	local v = nil
	pcall(function() v = M.num(obj[field]) end)
	return v
end

function M.write(obj, field, value)
	return (pcall(function() obj[field] = value end))
end

return M
