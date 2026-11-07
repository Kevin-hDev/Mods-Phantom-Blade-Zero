-- Game objects found by their path and kept from one frame to the next. UE4SS's IsValid only says that a live object
-- sits at the kept address (LuaUObject.hpp:763-766, UE4SS 1ceefac8): once the game unloads an object, another one can
-- take its address and pass as valid. So the class is checked again at each use. An object of another class handed
-- to the game would be read as the wrong type, a native crash that pcall cannot catch (crash audit, 4 November 2026);
-- the same check turns away whatever a game update could leave at the path.

local U = require("dodge_jump_unreal")

local M = {}

-- The class of the dodges the mod plays, and follows in the air.
M.MONTAGE = "/Script/Engine.AnimMontage"

local kept = {}                   -- by path

-- Whether obj is a live object of class: for any kept object handed to the game, found by path or not.
function M.usable(obj, class)
	if not U.is_valid(obj) then return false end
	local ok, yes = pcall(function() return obj:IsA(class) end)
	return ok and yes == true
end
local usable = M.usable

-- The object at path if it is of class (the class's full path, "/Script/Engine.AnimMontage"), nil otherwise.
function M.find(path, class)
	if usable(kept[path], class) then return kept[path] end
	local obj = nil
	pcall(function() obj = StaticFindObject(path) end)
	if not usable(obj, class) then obj = nil end
	kept[path] = obj
	return obj
end

-- A new pawn (a loaded save, a respawn): what the last level held may be gone.
function M.forget()
	kept = {}
end

return M
