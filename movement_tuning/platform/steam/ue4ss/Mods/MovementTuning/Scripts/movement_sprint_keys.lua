-- The sprint button's keys turned off and on again, for Turn off sprint: Sprint (movement_sprint_off.lua). The sprint
-- action's entries in the player's live key list are moved to a key name no PC sends, so the sprint never starts, while
-- the dodges, entries of their own on the same buttons, keep their keys; they are put back exactly, in the same order
-- (verified in game with SprintCutProbe, 7 November 2026). The game rebuilds that list from its control sets now and
-- then (twice around a held dodge in the probe), which gives the keys back. Unreal's RebuildControlMappings is no
-- UFUNCTION, so UE4SS cannot hook it: while the keys are off, the list's length and its first sprint entry are read
-- each frame, and a rebuild seen is cut again at once, before a press can start the sprint. Reading past the end of a
-- game array through UE4SS makes the array longer (UE4SS's LuaTArray.cpp, prepare_to_handle): an entry is read only
-- within the length just read. Another input layer over the game's takes keys out of that list while it is up: Mod
-- Panel's, open, holds every key the game maps, the sprint's and NO_KEY too (trial of 1.0.11, 7 November 2026); the
-- game's rebuild when it closes gives the list back whole.

local U = require("movement_unreal")

local M = {}

local NO_KEY = "Android_Back"   -- a key of Android phones: no PC sends it
local SPRINT = "IA_Sprint"      -- the sprint action's name, to match it while its address is not known
local MAX_MAPPINGS = 512        -- the player's live list holds 142 (verified in game)
local MAX_KEYS = 8              -- the sprint action has 3 keys
local SLOW_LOOK = 0.5           -- seconds between two whole looks while the quick check cannot be read
local SLOWEST_LOOK = 8          -- seconds: the longest wait between two whole looks for keys not found, doubled each time
local FRESH = 1                 -- seconds without a call to off: Sprint chosen anew (or the mod on again), looked for at
                                -- once rather than after the wait left by an earlier choice (1.4 s in the trial of 1.0.11)

-- keys: the sprint keys before the cut, by order among the sprint entries; nil while nothing is cut. first: the list
-- index of the first sprint entry, n: the list's length, both at the last cut. miss: the list's length at a look that
-- found no sprint entry, nil otherwise. action: the sprint action's address. next_look: the clock before which no whole
-- look is made again; wait: the seconds between looks for keys not found. last: the clock of the last call to off.
-- broken: the game refuses the change, said once. rebuilds: the rebuilds cut again since the last status line.
local K = { keys = nil, first = nil, n = nil, miss = nil, action = nil, next_look = 0, wait = SLOW_LOOK, last = nil,
	broken = false, said = {}, rebuilds = 0 }

local function say_once(say, what, fmt, ...)
	if K.said[what] then return end
	K.said[what] = true
	say(fmt, ...)
end

local function live_list(controller)
	local list = nil
	pcall(function() list = controller.PlayerInput.EnhancedActionMappings end)
	return list
end

local function length(list)
	local n = nil
	pcall(function() n = list:GetArrayNum() end)
	return U.num(n)
end

local function key_of(mapping)
	local key = nil
	pcall(function() key = mapping.Key.KeyName:ToString() end)
	return type(key) == "string" and key or nil
end

local function set_key(mapping, name)
	pcall(function() mapping.Key.KeyName = FName(name) end)
	return key_of(mapping) == name
end

-- The sprint entries, in order, and the list index of the first. Matched by the sprint action's address, one call an
-- entry; by its name, three, while no entry matched the address (the locomotion ability not found yet).
local function sprint_entries(items, ability)
	if K.action == nil then
		local a = nil
		pcall(function() a = ability.SprintInput end)
		K.action = U.is_valid(a) and U.address(a) or nil
	end
	local found, first, actions = {}, nil, {}
	for i, m in ipairs(items) do
		pcall(function() actions[i] = m.Action end)
		if #found < MAX_KEYS and K.action ~= nil and U.address(actions[i]) == K.action then
			found[#found + 1], first = m, first or i
		end
	end
	if #found > 0 then return found, first end
	for i, m in ipairs(items) do
		if #found < MAX_KEYS and U.name(actions[i]) == SPRINT then
			found[#found + 1], first = m, first or i
			K.action = U.address(actions[i])
		end
	end
	return found, first
end

-- Whether the entry is the sprint action's: by its address once known, else by its name.
local function is_sprint(mapping)
	local a = nil
	pcall(function() a = mapping.Action end)
	if K.action ~= nil then return U.address(a) == K.action end
	return U.name(a) == SPRINT
end

-- Puts back the keys moved in this call when the game refuses one of them: the sprint stays on, as in the game.
local function give_up(found, moved, say)
	for j, key in pairs(moved) do set_key(found[j], key) end
	K.broken, K.keys, K.first, K.n = true, nil, nil, nil
	say_once(say, "broken", "Turn off sprint: the game refuses to change the sprint's keys, the sprint stays on")
end

local function cut(list, ability, now, say)
	local items = U.items(list, MAX_MAPPINGS)
	local found, first = {}, nil
	if items ~= nil then found, first = sprint_entries(items, ability) end
	if #found == 0 then
		-- Watched by its length from now on when it can be read, else looked at again after the wait.
		K.miss = list ~= nil and length(list) or nil
		K.next_look, K.wait = now + K.wait, math.min(K.wait * 2, SLOWEST_LOOK)
		say_once(say, "missing", "Turn off sprint: the sprint's keys are not found in the key list, the sprint stays on "
			.. "(looked for again when the list changes)")
		return
	end
	local fresh, keys, moved, names = K.keys == nil, K.keys or {}, {}, {}
	for j, m in ipairs(found) do
		local key = key_of(m)
		if key ~= nil and key ~= NO_KEY then
			keys[j], moved[j], names[#names + 1] = key, key, key
			if not set_key(m, NO_KEY) then return give_up(found, moved, say) end
		end
	end
	K.keys, K.first, K.n, K.miss, K.next_look, K.wait = keys, first, length(list), nil, now + SLOW_LOOK, SLOW_LOOK
	if fresh then
		say("the sprint turned off: %s", #names > 0 and string.format("its keys %s moved to %s",
			table.concat(names, ", "), NO_KEY) or string.format("its keys were already on %s", NO_KEY))
	elseif #names > 0 then
		K.rebuilds = K.rebuilds + 1
	end
end

-- Each frame while the sprint is to be off. ability: the locomotion ability, nil while not found.
function M.off(controller, ability, now, say)
	if K.broken then return end
	if K.last == nil or now - K.last > FRESH then K.miss, K.next_look, K.wait = nil, 0, SLOW_LOOK end
	K.last = now
	if K.keys == nil and K.miss == nil and now < K.next_look then return end
	local list = live_list(controller)
	if K.miss ~= nil then
		-- No sprint entry at the last look: looked at again the frame the list's length changes (the input layer that
		-- hid them gone), and after the wait otherwise.
		if list ~= nil and length(list) == K.miss and now < K.next_look then return end
	elseif K.keys ~= nil then
		if list == nil then return end   -- nothing can be cut in a list that cannot be read: tried again next frame
		local n, key, entry = length(list), nil, nil
		if n ~= nil and n == K.n and K.first <= n then
			pcall(function() entry = list[K.first] end)
			key = key_of(entry)
		end
		-- The entry's action is not read (two calls more a frame): at the same length, NO_KEY at that place is the
		-- sprint's. The only other entries on NO_KEY come with another input layer, which changes the length.
		if key == NO_KEY then return end
		-- A real key back, or another length: the game rebuilt the list, cut again at once (a length that can no longer
		-- be read counts as another: one look, which keeps it unread). The same length with no entry read: a whole look
		-- at most every SLOW_LOOK seconds.
		if key == nil and n == K.n and now < K.next_look then return end
	end
	cut(list, ability, now, say)
end

-- Puts the keys back, the n-th sprint entry turned off taking the n-th key kept. An entry of the sprint hidden by
-- another input layer is not in the list: the game gives it back with the rest when it rebuilds the list.
function M.on(controller, say)
	if K.keys == nil then return end
	local keys, back, left, failed, kept, j = K.keys, {}, 0, 0, 0, 0
	K.keys, K.first, K.n, K.miss, K.next_look, K.wait = nil, nil, nil, nil, 0, SLOW_LOOK
	for _ in pairs(keys) do kept = kept + 1 end
	local items = U.items(live_list(controller), MAX_MAPPINGS)
	if items == nil then
		say("Turn off sprint: the key list cannot be read to give the sprint its keys back; the game gives them back when "
			.. "it reloads its controls, at the latest at the next launch")
		return
	end
	for _, m in ipairs(items) do
		if key_of(m) == NO_KEY and is_sprint(m) then
			j = j + 1
			if keys[j] == nil then
				left = left + 1
			elseif set_key(m, keys[j]) then
				back[#back + 1] = keys[j]
			else
				left, failed = left + 1, failed + 1
			end
		end
	end
	local hidden = kept - #back - failed
	say("the sprint turned on again: its keys %s back%s%s", #back > 0 and table.concat(back, ", ") or "none",
		left > 0 and string.format("; %d left off until the game reloads its controls", left) or "",
		hidden > 0 and string.format("; %d not in the key list now, given back when the game rebuilds it", hidden) or "")
end

function M.holding()
	return K.keys ~= nil
end

-- The rebuilds cut again since the last call, for the status line.
function M.rebuilds()
	local n = K.rebuilds
	K.rebuilds = 0
	return n
end

return M
