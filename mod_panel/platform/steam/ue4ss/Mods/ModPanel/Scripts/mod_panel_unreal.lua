-- Safe access to game objects through UE4SS: every call is wrapped, an unreadable value comes back as nil. Taken from
-- Dynamic FOV 1.0.4 (dynamic_fov_unreal.lua).

local M = {}

function M.num(v)
	v = tonumber(v)
	if v == nil or v ~= v then return nil end
	return v
end

-- Named, not a closure made at each call: is_valid runs several times a frame, and each closure was garbage (audit of
-- 0.4.3: 240 bytes a closed frame).
local function valid_of(obj) return obj:IsValid() end
local function address_of(obj) return obj:GetAddress() end

function M.is_valid(obj)
	if obj == nil then return false end
	local ok, valid = pcall(valid_of, obj)
	return ok and valid == true
end

function M.address(obj)
	local ok, a = pcall(address_of, obj)
	return ok and a or nil
end

local function to_string(v) return v:ToString() end

-- A string the engine gives back (an FString arrives as an object with ToString), or nil.
function M.text(v)
	if type(v) == "string" then return v end
	local ok, s = pcall(to_string, v)
	return ok and type(s) == "string" and s or nil
end

-- Looks objects up by path; a path not in memory is not looked for again until forget(). A miss is dear: UE4SS's
-- StaticFindObject asks the engine's hash tables, then walks every object of the game when they lack it (UEPseudo
-- 56bd812, UObjectGlobals.cpp, FindObject), milliseconds each (D174). A path found is looked for again at each call,
-- its object never kept: the game may free it in between (D75). The callers look for fixed lists of paths, so the
-- misses kept stay few.
function M.finder()
	local F, missing = {}, {}
	function F.find(path)
		if missing[path] then return nil end
		local ok, o = pcall(StaticFindObject, path)
		if ok and M.is_valid(o) then return o end
		missing[path] = true
		return nil
	end
	function F.forget() missing = {} end
	return F
end

-- The local player's subsystem of the class at class_path, asked of the controller pc through the engine's library
-- (D68), never looked for among the objects; nil when not given. The caller checks the library's function first
-- (Calls.FROM_PC).
function M.subsystem(pc, class_path)
	local lib, class = nil, nil
	pcall(function()
		lib, class = StaticFindObject("/Script/Engine.Default__SubsystemBlueprintLibrary"), StaticFindObject(class_path)
	end)
	if not M.is_valid(lib) or not M.is_valid(class) then return nil end
	local ok, sub = pcall(function() return lib:GetLocalPlayerSubSystemFromPlayerController(pc, class) end)
	return ok and M.is_valid(sub) and sub or nil
end

return M
