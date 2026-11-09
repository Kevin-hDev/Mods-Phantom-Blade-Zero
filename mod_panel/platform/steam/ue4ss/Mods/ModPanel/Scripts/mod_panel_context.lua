-- Mod Panel's own input context while the panel is open (D66): above all of the game's, it takes every controller key
-- and every key the game's actions use, keyboard and mouse included, so the game hears nothing while the panel reads
-- the controller. Unreal 5.7 (IEnhancedInputSubsystemInterface::RebuildControlMappings): a key mapped in a higher
-- context to an action that consumes its input is given to no lower context; IsInputKeyDown still reads the key's own
-- state (PadProbe pass 5, verified in game for the controller: 61 of the game's mappings on its keys before, none
-- with it).
-- The engine holds the context only while it is applied, and an object only Lua holds is destroyed, so the context is
-- made and applied in one frame, under a new name at each opening: the last one may not be destroyed yet. Taken from
-- PadProbe's pad_probe_swallow.lua and pad_probe_names.lua.

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")
local Names = require("mod_panel_pad_names")

local M = {}

local SUBSYSTEM = "/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem"
local CLASSES = "/Script/EnhancedInput."
local PRIORITY = 1000000          -- above the game's (its priorities are not read)
local MAX_KEYS = 200
local OWN = "ModPanel_Take_"
-- Rebuilt at once; keys held then trigger no action until let go (Unreal 5.7, FModifyContextOptions).
local OPTIONS = { bIgnoreAllPressedKeysUntilRelease = true, bForceImmediately = true, bNotifyUserSettings = false }
local COUNT_AFTER = 2             -- frames before the game's mappings are counted again

-- built: contexts made in this session, for their names. check: frames left before the count, 0 when none is due.
-- again: the context was put back once in this opening.
local S = { sub = nil, ctx = nil, taken = nil, built = 0, before = 0, check = 0, again = false }

-- Runs fn on each element of an Unreal array, until fn returns true: UE4SS's ForEach then stops its walk. It is given
-- true or nothing, never false: a false breaks the walk at that element (LuaTArray.cpp, lines 158 to 168). In 0.4.4 it
-- was given false, and the panel took 34 keys instead of 75, the keyboard and the mouse left to the game (trial of
-- 0.4.4, verified in game).
local function each(arr, fn)
	pcall(function()
		arr:ForEach(function(_, e)
			local v = e
			pcall(function() v = e:get() end)
			if fn(v) == true then return true end
		end)
	end)
end

local function key_of(m)
	local ok, name = pcall(function() return m.Key.KeyName:ToString() end)
	return ok and type(name) == "string" and name ~= "None" and name or nil
end

local function ours(m)
	local ok, name = pcall(function() return m.Action:GetFName():ToString() end)
	return ok and type(name) == "string" and name:sub(1, #OWN) == OWN
end

-- Runs fn on each mapping of the player's input as the engine built it.
local function each_mapping(pc, fn)
	local arr = nil
	pcall(function() arr = pc.PlayerInput.EnhancedActionMappings end)
	if arr ~= nil then each(arr, fn) end
end

-- The keys to take: the controller's, then every key the game maps now, each once. Returns them, how many are the
-- controller's, and the set of their names.
local function wanted(pc)
	local list, seen = {}, {}
	local function add(name)
		if name ~= nil and not seen[name] and #list < MAX_KEYS then
			seen[name] = true
			list[#list + 1] = name
		end
	end
	for _, b in ipairs(Names.BUTTONS) do add(b[1]) end
	for _, a in ipairs(Names.AXES) do add(a) end
	local pad = #list
	each_mapping(pc, function(m) add(key_of(m)) end)
	return list, pad, seen
end

-- The game's mappings on the keys taken, ours left out.
local function game_mappings(pc)
	local n = 0
	each_mapping(pc, function(m)
		local key = key_of(m)
		if key ~= nil and S.taken[key] and not ours(m) then n = n + 1 end
	end)
	return n
end

-- Once a second: the walk stops at the first of our mappings (audit of 0.4.3), not after the whole list.
local function present(pc)
	local found = false
	each_mapping(pc, function(m)
		found = ours(m)
		return found
	end)
	return found
end

local function build(outer, keys)
	S.built = S.built + 1
	-- The time too: when UE4SS loads the scripts again, built starts again at 0 while the older contexts may live on.
	local suffix = S.built .. "_" .. tostring(os.time())
	local function class(name)
		local c = StaticFindObject(CLASSES .. name)
		assert(U.is_valid(c), name .. " not found")
		return c
	end
	local action = StaticConstructObject(class("InputAction"), outer, FName(OWN .. "Action_" .. suffix))
	local ctx = StaticConstructObject(class("InputMappingContext"), outer, FName(OWN .. "Context_" .. suffix))
	local mapped = 0
	for _, name in ipairs(keys) do
		if pcall(function() ctx:MapKey(action, { KeyName = FName(name) }) end) then mapped = mapped + 1 end
	end
	return ctx, mapped
end

-- Whether every function the context needs is in the game as this version knows it.
function M.usable()
	return Calls.ok(Calls.ADD_CONTEXT) and Calls.ok(Calls.REMOVE_CONTEXT) and Calls.ok(Calls.MAP_KEY)
		and Calls.ok(Calls.FROM_PC) and Calls.ok(Calls.GAME_AND_UI)
end

-- Makes and applies the context for pc, gi the game instance. Returns true, or false and why.
function M.on(pc, gi)
	if S.ctx ~= nil then return true end
	if not M.usable() then return false, "a function it needs is not the one this version knows" end
	local sub = U.subsystem(pc, SUBSYSTEM)
	if sub == nil then return false, "the player's input subsystem is not given" end
	local keys, pad, seen = wanted(pc)
	S.taken = seen
	S.before = game_mappings(pc)
	local ok, ctx, mapped = pcall(build, gi, keys)
	if not ok then return false, "it could not be made (" .. tostring(ctx) .. ")" end
	local added, err = pcall(function() sub:AddMappingContext(ctx, PRIORITY, OPTIONS) end)
	if not added then return false, "it could not be applied (" .. tostring(err) .. ")" end
	S.sub, S.ctx, S.check = sub, ctx, COUNT_AFTER
	return true, string.format("%d of %d keys taken (%d controller, %d keyboard and mouse)", mapped, #keys, pad,
		#keys - pad)
end

local function remove(sub, ctx) sub:RemoveMappingContext(ctx, OPTIONS) end

-- Takes the context off; it is forgotten either way. Returns a line for the log, or nil when none was on, and whether
-- it tells a failure. The put back is reset even then: a put back that failed leaves no context, and the next opening
-- may put one back again.
function M.off()
	S.again = false
	if S.ctx == nil then return nil end
	local sub, ctx = S.sub, S.ctx
	S.sub, S.ctx, S.check = nil, nil, 0
	if not U.is_valid(sub) or not U.is_valid(ctx) then return "input context gone, nothing to take off" end
	local ok, err = pcall(remove, sub, ctx)
	if ok then return "input context off" end
	return "input context: taking it off failed: " .. tostring(err), true
end

function M.on_now() return S.ctx ~= nil end

-- At each frame of the open panel: the game's mappings on the keys taken, counted again once, as a line for the log.
function M.frame(pc)
	if S.check == 0 then return nil end
	S.check = S.check - 1
	if S.check > 0 then return nil end
	return string.format("the game's mappings on the keys taken: %d before our input context, %d with it", S.before,
		game_mappings(pc))
end

-- Once a second while the panel is open: the context put back once if the game took it off. Returns a line for the
-- log, and a reason to close the panel when the game took it off again.
function M.second(pc, gi)
	if S.ctx == nil or present(pc) then return nil end
	if S.again then
		M.off()
		return nil, "the game took the panel's controls back"
	end
	-- The old one taken off first: the mappings may only have been unreadable, the context still on, and it would stay
	-- on the controller for good (audit of 0.4.3). Unreal 5.7 does nothing for a context no longer applied.
	local sub, ctx = S.sub, S.ctx
	S.sub, S.ctx = nil, nil
	if U.is_valid(sub) and U.is_valid(ctx) then pcall(remove, sub, ctx) end
	local ok, why = M.on(pc, gi)
	S.again = true
	return "input context: the game took it off, put back: " .. tostring(why), not ok and why or nil
end

return M
