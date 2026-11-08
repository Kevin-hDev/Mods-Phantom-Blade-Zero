-- The game's own jump keys, read where the engine keeps the player's mappings as it built them: the keys mapped to
-- IA_Jump in PlayerInput.EnhancedActionMappings (Cross and Space by default); the action alone lists no key.
-- Read when the character is ready, then every RECHECK s, so that a key changed in the game's options is followed.
-- Reading the whole list, some 142 mappings, takes 0.70 ms (measured in game): too much for each frame.
-- A mapping without an action is passed over before its name is asked, since UE4SS's GetFName crashes on an unset
-- object past any pcall; and the walk stops at its bounds, UE4SS's ForEach stopping only when its function returns
-- true. The keys are kept the controller's first, then the others, each group in alphabetical order: the same keys
-- read in another order are not a change.

local R = require("vault_reading")
local Status = require("vault_status")

local M = {}

local JUMP = "IA_Jump"
local DEFAULT = { "Gamepad_FaceButton_Bottom", "SpaceBar" } -- the game's own, Cross and Space, until a read finds them
local RECHECK = 10                -- s between two reads
local RETRY = 1                   -- s between two reads while a new character's keys are not found yet
local MAX_TRIES = 10              -- reads at RETRY s for a new character, before RECHECK
local MAX_MAPPINGS = 1000         -- the game has 142; the rest of a longer list is not looked at
local MAX_KEYS = 8

-- keys: the keys watched; found: a read found some since the mod started; fresh: a new character whose keys are not
-- found yet; tries: reads that found none for it, at RETRY s while fewer than MAX_TRIES; next: when to read again;
-- said: the unread keys were said.
local S = { keys = DEFAULT, found = false, fresh = true, tries = 0, next = 0, said = false }

local function name_of(fn)
	local ok, name = pcall(fn)
	return ok and type(name) == "string" and name ~= "None" and name or nil
end

local function pad_first(a, b)
	local pad_a, pad_b = a:find("^Gamepad_") ~= nil, b:find("^Gamepad_") ~= nil
	if pad_a ~= pad_b then return pad_a end
	return a < b
end

-- The keys mapped to IA_Jump now, each once, the controller's first; nil when the list cannot be read.
local function read(controller)
	-- Checked first: a call on an unset object can crash past any pcall (GetClass does).
	local input = R.read(function() return controller.PlayerInput end)
	if not R.is_valid(input) then return nil end
	local arr = R.read(function() return input.EnhancedActionMappings end)
	if arr == nil then return nil end
	local keys, seen, n = {}, {}, 0
	local ok = pcall(function()
		arr:ForEach(function(_, e)
			n = n + 1
			if n > MAX_MAPPINGS or #keys >= MAX_KEYS then return true end
			local m = R.unwrap(e)
			local action = R.field(m, "Action")
			if not R.is_valid(action) then return end
			if name_of(function() return action:GetFName():ToString() end) ~= JUMP then return end
			local key = name_of(function() return m.Key.KeyName:ToString() end)
			if key ~= nil and not seen[key] then
				seen[key] = true
				keys[#keys + 1] = key
			end
		end)
	end)
	if not ok then return nil end
	table.sort(keys, pad_first)
	return keys
end

local function same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

-- A read that found no key: the keys found before stay, a menu's mappings may hold no jump.
local function missed(say, now)
	if not S.fresh then return end
	S.tries = S.tries + 1
	if S.tries < MAX_TRIES then
		S.next = now + RETRY
	elseif not S.found and not S.said then
		S.said = true
		say("the game's jump keys cannot be read; watching %s, the game's own, and reading again every %d s",
			table.concat(S.keys, " and "), RECHECK)
	end
end

-- The keys to watch now.
function M.keys()
	return S.keys
end

-- Each frame while the mod acts: reads the keys when it is time. Returns true when the keys watched changed.
function M.frame(say, controller, now)
	if now < S.next then return false end
	S.next = now + RECHECK
	Status.note("the game's jump keys")
	local keys = read(controller)
	if keys == nil or #keys == 0 then
		missed(say, now)
		return false
	end
	local changed, first = not same(keys, S.keys), not S.found
	S.found, S.fresh = true, false
	if not changed and not first then return false end
	S.keys = keys
	say("the game's jump keys: %s", table.concat(keys, ", "))
	return changed
end

-- A character ready (a new one, or the mod switched on): its keys read at once.
function M.reset()
	S.next, S.fresh, S.tries = 0, true, 0
end

return M
