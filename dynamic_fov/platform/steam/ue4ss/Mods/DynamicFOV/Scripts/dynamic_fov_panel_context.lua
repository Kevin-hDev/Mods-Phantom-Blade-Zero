-- The panel's own input context while it is open: above all of the game's, it takes every controller key and every
-- key the game's actions use, keyboard and mouse included, so the game hears nothing while the panel reads the
-- controller. Unreal 5.7 (IEnhancedInputSubsystemInterface::RebuildControlMappings): a key mapped in a higher context
-- to an action that consumes its input is given to no lower context; IsInputKeyDown still reads the key's own state.
-- Verified in game on 7 November 2026: 75 keys taken, the game's 142 mappings on them down to none, the character, the
-- camera and the game's menus still.
-- The engine holds the context only while it is applied, and an object only Lua holds is destroyed, so the context is
-- made and applied in one frame, under a new name at each opening: the last one may not be destroyed yet.

local U = require("dynamic_fov_unreal")
local PanelCalls = require("dynamic_fov_panel_calls")
local Game = require("dynamic_fov_panel_game")
local Names = require("dynamic_fov_panel_pad_names")

local M = {}

local SUBSYSTEM = "/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem"
local CLASSES = "/Script/EnhancedInput."
local PRIORITY = 1000000          -- above the game's (its priorities are not read)
local MAX_KEYS = 200
local OWN = "DynamicFOV_Take_"
-- Rebuilt at once; keys held then trigger no action until let go (Unreal 5.7, FModifyContextOptions).
local OPTIONS = { bIgnoreAllPressedKeysUntilRelease = true, bForceImmediately = true, bNotifyUserSettings = false }
local COUNT_AFTER = 2             -- frames before the game's mappings are counted again

-- built: contexts made in this session, for their names. check: frames left before the count, 0 when none is due.
-- again: the context was put back once in this opening.
local S = { sub = nil, ctx = nil, taken = nil, built = 0, before = 0, check = 0, again = false }

-- Runs fn on each element of an Unreal array.
local function each(arr, fn)
	pcall(function()
		arr:ForEach(function(_, e)
			local v = e
			pcall(function() v = e:get() end)
			fn(v)
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
-- controller's, and the set of them.
local function wanted(pc)
	local list, seen = {}, {}
	local function add(name)
		if name ~= nil and not seen[name] and #list < MAX_KEYS then
			seen[name] = true
			list[#list + 1] = name
		end
	end
	for _, b in ipairs(Names.BUTTONS) do add(b) end
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

local function present(pc)
	local found = false
	each_mapping(pc, function(m) if not found and ours(m) then found = true end end)
	return found
end

local function build(outer, keys)
	S.built = S.built + 1
	-- The time too: when UE4SS loads the scripts again, built starts again at 0 while the older contexts may live on.
	local suffix = S.built .. "_" .. tostring(os.time())
	local function class(name)
		local c = Game.find(CLASSES .. name)
		assert(c ~= nil, name .. " not found")
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
	return PanelCalls.ok(PanelCalls.ADD_CONTEXT) and PanelCalls.ok(PanelCalls.REMOVE_CONTEXT)
		and PanelCalls.ok(PanelCalls.MAP_KEY) and PanelCalls.ok(PanelCalls.FROM_PC)
		and PanelCalls.ok(PanelCalls.GAME_AND_UI)
end

-- Makes and applies the context for pc, gi the game instance. Returns true, or false and why.
function M.on(pc, gi)
	if S.ctx ~= nil then return true end
	if not M.usable() then return false, "a function it needs is not the one this version knows" end
	-- Kept from the opening when put back: never an owner the engine has destroyed.
	if not U.is_valid(gi) then return false, "the game instance is gone" end
	local sub = Game.subsystem(pc, SUBSYSTEM)
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

-- Takes the context off; it is forgotten either way. Returns a line for the log, or nil when none was on. The put
-- back is reset even then: a put back that failed leaves no context, and the next opening may put one back again.
function M.off()
	S.again = false
	if S.ctx == nil then return nil end
	local sub, ctx = S.sub, S.ctx
	S.sub, S.ctx, S.check = nil, nil, 0
	if not U.is_valid(sub) or not U.is_valid(ctx) then return "input context gone, nothing to take off" end
	local ok, err = pcall(function() sub:RemoveMappingContext(ctx, OPTIONS) end)
	return ok and "input context off" or ("input context: taking it off failed: " .. tostring(err))
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
	-- Taken off first: the reading may have failed with the context still applied, and a context forgotten while
	-- applied would keep the game's keys after the panel closes (audit of 1.0.5).
	M.off()
	local ok, why = M.on(pc, gi)
	S.again = true
	return "input context: the game took it off, put back: " .. tostring(why), not ok and why or nil
end

return M
