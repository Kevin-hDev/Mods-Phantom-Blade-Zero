-- Safe access to game objects through UE4SS: every call is wrapped, an unreadable value comes back as nil.

local M = {}

-- CharacterMovement.MovementMode: none, on the ground, in a jump or a fall; special moves run in other modes (5).
M.NONE, M.WALKING, M.FALLING = 0, 1, 3
-- Seconds: a longer frame is a pause or a load, and what was being measured across it is dropped.
M.PAUSE = 0.25
-- An acceleration above this, in cm/s a second: the game takes the stick (it gives zero while it ignores the stick).
M.PUSHED = 1

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
local function velocity_of(cmc) return cmc.Velocity end
local function acceleration_of(cmc) return cmc:GetCurrentAcceleration() end
local function yaw_of(actor) return actor:K2_GetActorRotation().Yaw end

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

-- The movement component's velocity, flat: x, y and its size; nil when unreadable.
function M.velocity(cmc)
	local ok, v = pcall(velocity_of, cmc)
	if not ok then return nil end
	return M.flat(v)
end

-- The acceleration the game gives from the stick, flat: x, y and its size; nil when unreadable.
function M.acceleration(cmc)
	local ok, a = pcall(acceleration_of, cmc)
	if not ok then return nil end
	return M.flat(a)
end

-- The actor's facing, in degrees from -180 to 180; nil when unreadable.
function M.yaw(actor)
	local ok, yaw = pcall(yaw_of, actor)
	return ok and M.num(yaw) or nil
end

-- The signed angle from the yaw b to the yaw a, -180 to 180 deg.
function M.angle(a, b)
	return (a - b + 540) % 360 - 180
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
