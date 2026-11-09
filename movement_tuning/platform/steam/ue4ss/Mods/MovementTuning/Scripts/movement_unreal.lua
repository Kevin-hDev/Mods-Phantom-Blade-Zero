-- Safe access to game objects through UE4SS: every call is wrapped, an unreadable value comes back as nil.

local M = {}

function M.num(v)
	v = tonumber(v)
	if v == nil or v ~= v then return nil end
	return v
end

-- Called through pcall by name: a closure made at each call would be made some twenty times a frame.
local function valid_of(obj) return obj:IsValid() end
local function address_of(obj) return obj:GetAddress() end
local function get_of(p) return p:get() end
local function class_address_of(obj) return obj:GetClass():GetAddress() end

function M.is_valid(obj)
	if obj == nil then return false end
	local ok, valid = pcall(valid_of, obj)
	return ok and valid == true
end

function M.address(obj)
	if obj == nil then return nil end
	local ok, a = pcall(address_of, obj)
	return ok and a or nil
end

-- Hook parameters arrive wrapped; plain values pass through.
function M.unwrap(p)
	if p == nil then return nil end
	local ok, v = pcall(get_of, p)
	if ok then return v end
	return p
end

-- UE4SS's GetClass has no null check: on an unset property it crashes past any pcall, so both functions below check
-- the object first.

-- The address of the object's class, a cheap way to tell two objects at one address apart. checked: the caller has
-- just checked the object valid.
function M.class_address(obj, checked)
	if not checked and not M.is_valid(obj) then return nil end
	local ok, a = pcall(class_address_of, obj)
	return ok and a or nil
end

function M.class_name(obj)
	if not M.is_valid(obj) then return nil end
	local ok, n = pcall(function() return obj:GetClass():GetFName():ToString() end)
	return ok and type(n) == "string" and n or nil
end

-- The object's own name, for the log.
function M.name(obj)
	if not M.is_valid(obj) then return nil end
	local ok, n = pcall(function() return obj:GetFName():ToString() end)
	return ok and type(n) == "string" and n or nil
end

-- The items of a game array (TArray, or a TMap's values), walked once: only UE4SS's walk is in the pcall, so an error in
-- the mod's own code that works on them reaches the error count and the log. Returns nil when the walk fails.
function M.items(array, max)
	if array == nil then return nil end
	local list = {}
	local ok = pcall(function()
		array:ForEach(function(_, item)
			if #list < max then list[#list + 1] = M.unwrap(item) end
		end)
	end)
	return ok and list or nil
end

-- A vector's flat part (a velocity or an acceleration): x, y and its size; nil when unreadable.
function M.flat(v)
	local x, y = nil, nil
	pcall(function() x, y = tonumber(v.X), tonumber(v.Y) end)
	if x == nil or y == nil or x ~= x or y ~= y then return nil end
	return x, y, math.sqrt(x * x + y * y)
end

-- Whether the player holds the key (key: an FKey table { KeyName = FName }); false when it cannot be read.
function M.key_down(controller, key)
	local ok, v = pcall(function() return controller:IsInputKeyDown(key) end)
	return ok and v == true
end

-- The pawn's movement component and its MovementMode, read once a frame for the ground speeds and the jump height;
-- nil when the component cannot be read.
function M.movement(pawn)
	local cmc = nil
	pcall(function() cmc = pawn.CharacterMovement end)
	if not M.is_valid(cmc) then return nil, nil end
	local mode = nil
	pcall(function() mode = M.num(cmc.MovementMode) end)
	return cmc, mode
end

return M
