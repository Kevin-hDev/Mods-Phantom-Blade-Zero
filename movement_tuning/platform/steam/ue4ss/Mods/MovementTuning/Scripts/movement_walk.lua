-- The game's walk with auto sprint: the only presser of the walk action.
--
-- The game's walk on the keyboard (Left Alt by default, the locomotion ability's WalkInput, IA_Walk) is a switch: each
-- press turns it on or off. The game marks its walk with the Walking tag (movement_tags.lua), which also comes when a
-- light push of the stick walks. While a sprint is pressed, the game
-- ignores the press: the tag never came, 26 presses out of 26 (verified in game, 5 November 2026). So when the player
-- presses a walk key while auto sprint presses the sprint, the mod lets the sprint go, waits for the game's sprint to
-- end and presses the walk once; while the tag is there, auto sprint stays off.

local U = require("movement_unreal")
local Press = require("movement_press")
local Tags = require("movement_tags")

local M = {}

local LOOK_EVERY = 5      -- seconds between two reads of the walk keys: the player can change them in the game's controls
local MAX_EMPTY = 3       -- reads in a row that find no walk key before the keys found are dropped: the game's key set
                          -- can lack the walk for one read (seen in game), and the player can unbind it
local MAX_KEYS = 8
local MAX_MAPPINGS = 512  -- the player has about 140 key mappings
local SPRINT_WAIT = 0.5   -- seconds a walk asked waits at most for the game's sprint to end
local RETRY = 0.25        -- seconds before pressing again a walk the game did not take; its tag shows within 0.04 s
local FIRST_PRESS = 0.05  -- seconds before the first press: the game may have taken the player's own press, then its tag
                          -- is there and a press of the mod's would turn the walk off again
local FIRST_FRAMES = 2    -- frames after the key, at least, before the first press: at a low frame rate 0.05 s is a frame
local SPRINT_AFTER = 0.15 -- seconds after auto sprint's last press that a walk key still finds the game sprinting: its
                          -- sprint ends 0.08 s after the last press (verified in game)
local MAX_TRIES = 3

-- Per character: the walk keys (found: some were read once) and action, the walk key held last frame, the walk asked
-- (pending: { since, tries, next, frames }), auto sprint's last press (sprint_at). wait: the first frame with the ability
-- is left to the stick's work. walks, missed: for the status line, kept across characters.
local G

function M.forget()
	G = { next_look = 0, keys = {}, empty = 0, found = false, action = nil, down = false,
		pending = nil, sprint_at = nil, wait = true, failed = false, said = {}, walks = G and G.walks or 0,
		missed = G and G.missed or 0 }
end
M.forget()

local function say_once(say, what, fmt, ...)
	if G.said[what] then return end
	G.said[what] = true
	say(fmt, ...)
end

local function walk_action(ability)
	if not U.is_valid(G.action) then pcall(function() G.action = ability.WalkInput end) end
	return G.action
end

local function add_key(keys, mapping)
	local key = nil
	pcall(function() key = mapping.Key.KeyName:ToString() end)
	if #keys < MAX_KEYS and type(key) == "string" and key ~= "None" then keys[#keys + 1] = { KeyName = FName(key) } end
end

-- The keys bound to the walk action, as FKey tables for IsInputKeyDown, and how many key mappings were read. A mapping's
-- action is matched by its address, one call; by its name, three, only when no address matched.
local function walk_keys(controller, ability, say)
	local action, mappings = walk_action(ability), nil
	local target = U.is_valid(action) and U.address(action) or nil
	if target == nil then return {}, 0 end
	pcall(function() mappings = controller.PlayerInput.EnhancedActionMappings end)
	local list, keys, actions = U.items(mappings, MAX_MAPPINGS) or {}, {}, {}
	for i, m in ipairs(list) do
		pcall(function() actions[i] = m.Action end)
		if U.address(actions[i]) == target then add_key(keys, m) end
	end
	local how = "address"
	if #keys == 0 then
		local name = U.name(action)
		for i, m in ipairs(list) do
			if name ~= nil and U.name(actions[i]) == name then add_key(keys, m) end
		end
		how = "name"
	end
	if #keys > 0 then say_once(say, "match", "the game's walk keys: %d, found by the action's %s", #keys, how) end
	return keys, #list
end

local function look(controller, ability, say)
	-- A read without the walk keeps the keys found before, up to MAX_EMPTY reads.
	local keys, read = walk_keys(controller, ability, say)
	if #keys > 0 then
		G.keys, G.empty, G.found = keys, 0, true
		return
	end
	G.empty = G.empty + 1
	if G.empty < MAX_EMPTY then return end
	G.keys = {}
	if not G.found then
		say_once(say, "keys", "the game's walk keys cannot be read (%d key mappings read): auto sprint does not stop for "
			.. "them", read)
	end
end

-- The walk asked: settled once the game walks, pressed again a few times when it does not take the press.
local function settle(walking, now, ability, say)
	local p = G.pending
	if walking then
		G.pending, G.walks = nil, G.walks + 1
		return
	end
	p.frames = p.frames + 1
	if now < p.next or p.frames <= FIRST_FRAMES then return end
	if p.tries >= MAX_TRIES then
		G.pending, G.missed = nil, G.missed + 1
		return
	end
	if Tags.has("sprinting") == true and now - p.since < SPRINT_WAIT then return end
	local _, err = Press.action(walk_action(ability))
	if err ~= nil then
		G.failed, G.pending = true, nil
		say("the game's walk cannot be pressed (%s): auto sprint does not stop for it", tostring(err))
		return
	end
	p.tries, p.next = p.tries + 1, now + RETRY
end

-- auto: auto sprint is on. sprinting: auto sprint pressed the sprint last frame. Returns true when auto sprint must
-- stay off this frame: the game walks, or a walk is asked.
function M.frame(controller, pawn, ability, now, auto, sprinting, say)
	if ability == nil or G.failed or not auto then
		G.pending, G.down, G.sprint_at = nil, false, nil
		return false
	end
	if G.wait then
		G.wait = false
		return false
	end
	if now >= G.next_look then
		G.next_look = now + LOOK_EVERY
		look(controller, ability, say)
	end
	if not Tags.look(pawn, now) then
		G.pending = nil
		if Tags.gave_up() and not Tags.broken() then
			say_once(say, "config", "the game's walk cannot be found: auto sprint does not stop for it")
		end
		return false
	end
	local walking = Tags.has("walking")
	if walking == nil then
		G.pending = nil
		say_once(say, "tag", "the game's walk cannot be read: auto sprint does not stop for it")
		return false
	end
	local down = false
	for _, key in ipairs(G.keys) do down = down or U.key_down(controller, key) end
	if sprinting then G.sprint_at = now end
	local sprint_on = G.sprint_at ~= nil and now - G.sprint_at < SPRINT_AFTER
	if down and not G.down and sprint_on and not walking and G.pending == nil then
		G.pending = { since = now, tries = 0, next = now + FIRST_PRESS, frames = 0 }
	end
	G.down = down
	if G.pending ~= nil then settle(walking, now, ability, say) end
	return walking or G.pending ~= nil
end

function M.report()
	local text = string.format("%d walks kept from auto sprint, %d not taken by the game", G.walks, G.missed)
	G.walks, G.missed = 0, 0
	return text
end

return M
