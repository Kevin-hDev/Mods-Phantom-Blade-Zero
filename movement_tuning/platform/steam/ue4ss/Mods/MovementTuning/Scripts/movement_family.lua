-- The setting an ability follows, from its family: its class and the classes it comes from, read up with UE4SS's
-- GetSuperStruct as UE4SS's own dump_object.lua does, then sorted by movement_moves.lua. Read once per class and kept by
-- the class's address until the next character (forget).

local U = require("movement_unreal")
local Moves = require("movement_moves")
local Tasks = require("movement_tasks")

local M = {}

local MAX_DEPTH = 24       -- classes read up from an ability; the game's deepest player ability has 12 (type map)
local MAX_CLASSES = 512    -- classes remembered; past this, the memory starts over
local MAX_NOTES = 48       -- abilities written to the log with the setting they follow, once each, per session

local F = { keys = {}, count = 0, noted = {}, notes = 0, flat_said = false }

-- The classes are read anew; the abilities already written stay written.
function M.forget()
	F.keys, F.count = {}, 0
end

-- The class's name and those of the classes it comes from; also read by movement_enemy_names.lua.
function M.names(class)
	local names, cur = {}, class
	while #names < MAX_DEPTH and U.is_valid(cur) do
		local name = nil
		pcall(function() name = cur:GetFName():ToString() end)
		if type(name) ~= "string" then break end
		names[#names + 1] = name
		local super = nil
		pcall(function() super = cur:GetSuperStruct() end)
		cur = super
	end
	return names
end

-- The first abilities sorted are written to the log, to check the families in game; an ability whose parent classes
-- cannot be read is sorted by its name alone, said once.
local function note(names, key, say)
	if #names == 1 and not F.flat_said then
		F.flat_said = true
		say("the classes %s comes from cannot be read: abilities are told apart by their name alone", names[1])
	end
	if F.notes >= MAX_NOTES or F.noted[names[1]] then return end
	F.noted[names[1]], F.notes = true, F.notes + 1
	say("%s follows %s", names[1], key and key or "the game's pace")
end

-- The key of the setting obj's class follows, false for one the mod leaves alone, nil when its class cannot be read.
function M.category(obj, say)
	if not U.is_valid(obj) then return nil end
	local class = nil
	pcall(function() class = obj:GetClass() end)
	local addr = U.address(class)
	if addr == nil then return nil end
	local key = F.keys[addr]
	if key ~= nil then return key end
	local names = M.names(class)
	if #names == 0 then return nil end
	key = Moves.category(names) or false
	if F.count >= MAX_CLASSES then F.keys, F.count = {}, 0 end
	F.keys[addr], F.count = key, F.count + 1
	note(names, key, say)
	return key
end

-- What one of the player's tasks is, for movement_speed.lua: { task, key, class, ability (their addresses), fresh },
-- { key = false } for one left alone, nil when it cannot be read this frame (tried again next frame).
function M.entry(task, say)
	local timeline, class = Tasks.is_timeline(task)
	if timeline == nil then return nil end
	if not timeline then return { key = false } end
	local ability = nil
	pcall(function() ability = task.Ability end)
	-- UE4SS gives an unset object property as an object that is not valid.
	if not U.is_valid(ability) then return { key = false } end
	local key = M.category(ability, say)
	if key == nil then return nil end
	return { task = task, key = key, class = class, ability = U.address(ability), fresh = true }
end

return M
