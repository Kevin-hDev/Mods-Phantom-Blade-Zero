-- Which abilities are executions: the game's own families, read up from the ability's class with UE4SS's
-- GetSuperStruct, as UE4SS's dump_object.lua does. The game films most executions in the combat view in progress, not
-- in a view of their own (an execution in the air has one, cameraMode.AirExecution; trials of 10 November 2026):
-- their families are what tells them apart.

local U = require("dynamic_fov_unreal")

local M = {}

-- From the game's type map (ProjectPBZ 5.7.4, read 10 November 2026): executions given (in combat, unseen, in the air,
-- grabs, the special weapons'), taken (an enemy's or a boss's, on the player), their second parts, the quick ones on a
-- weakened enemy, and those after a perfect dodge.
M.FAMILIES = { "GA_ExecutionAbilityBase_C", "GA_ExecutedAbilityBase_C", "GA_ContinuousExecutionSimple_Base_C",
	"GA_SimpleExecution_Base_C", "BP_Hun_PerfectDodge_ExecutionBase_C" }
-- The one grab execution outside those families: a perfect dodge's, with the dual hooks (type map).
M.CLASSES = { "GA_Hun_DualHook_PerfectDodge_GEx_C" }

local MAX_DEPTH = 24       -- classes read up from an ability; the game's deepest has 12 (type map)
local MAX_CLASSES = 512    -- classes remembered; past this, the memory starts over

local EXECUTIONS = {}
for _, name in ipairs(M.FAMILIES) do EXECUTIONS[name] = true end
for _, name in ipairs(M.CLASSES) do EXECUTIONS[name] = true end

-- known: class address -> { execution = bool, name = the class's name }.
local F = { known = {}, count = 0, flat_said = false }

local function class_of(obj) return obj:GetClass() end
local function super_of(class) return class:GetSuperStruct() end
local function name_of(obj) return obj:GetFName():ToString() end

-- The class's name, whether it or a class it comes from is an execution's, and how many classes were read.
local function read(class)
	local first, cur, depth = nil, class, 0
	while depth < MAX_DEPTH and U.is_valid(cur) do
		local ok, name = pcall(name_of, cur)
		if not ok or type(name) ~= "string" then break end
		first, depth = first or name, depth + 1
		if EXECUTIONS[name] then return first, true, depth end
		local oks, super = pcall(super_of, cur)
		cur = oks and super or nil
	end
	return first, false, depth
end

-- The address of obj's class, or nil. UE4SS's GetClass has no null check: obj is checked first.
function M.class_address(obj)
	if not U.is_valid(obj) then return nil end
	local ok, class = pcall(class_of, obj)
	if not ok or not U.is_valid(class) then return nil end
	return U.address(class)
end

-- Whether ability is an execution, the name of its class and the class's address; nil when its class cannot be
-- read. say(fmt, ...) hears, once, that the classes an ability comes from cannot be read: every ability comes at least
-- from GameplayAbility and Object (type map), so one read alone is a failure, and executions are then not told apart.
function M.of(ability, say)
	if not U.is_valid(ability) then return nil end
	local okc, class = pcall(class_of, ability)
	if not okc or not U.is_valid(class) then return nil end
	local addr = U.address(class)
	if addr == nil then return nil end
	local known = F.known[addr]
	if known ~= nil then return known.execution, known.name, addr end
	local name, execution, depth = read(class)
	if name == nil then return nil end
	if depth == 1 and not execution then
		if not F.flat_said then
			F.flat_said = true
			say("execution watch: the classes %s comes from cannot be read; executions are not told apart, the camera "
				.. "stays the player's during them", name)
		end
		-- Not remembered: a read that failed once is tried again with the next ability of this class.
		return false, name, addr
	end
	if F.count >= MAX_CLASSES then F.known, F.count = {}, 0 end
	F.known[addr], F.count = { execution = execution, name = name }, F.count + 1
	return execution, name, addr
end

-- A load: the classes are read anew, at whatever address they now sit.
function M.forget()
	F.known, F.count = {}, 0
end

return M
