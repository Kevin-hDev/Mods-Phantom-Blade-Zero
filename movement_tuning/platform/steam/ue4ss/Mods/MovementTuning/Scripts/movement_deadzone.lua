-- The sticks' dead zones (Enhanced Input's InputModifierDeadZone on the stick actions): the only file that writes them.
-- The player's live copy of an action is made from the action when the player's input is built, and the game can throw
-- it away and make it again (Unreal 5.7: InputAction.cpp, EnhancedInputSubsystemInterface.cpp). So the mod writes the
-- action's own dead zone, which the copies made later take, and the live copies there are at that moment. The game's
-- value is kept before the mod writes, and given back where the mod's is still in place.

local U = require("movement_unreal")

local M = {}

local DEAD_ZONE = "InputModifierDeadZone"
local SAME = 1e-4          -- the threshold is a 32-bit float: a value written reads back rounded
local MAX_MODIFIERS = 16   -- an action carries 1 to 3 (verified in game)
local MAX_ACTIONS = 512    -- live copies looked at; the player has about 100 actions
local STICKS = { move = "left stick", look = "right stick" }

-- By stick: action (the action's address), modifier (its own dead zone), game (the game's value), mine (the mod's value,
-- nil when none is in place), said (the log said the action has no dead zone), mapped (its key mappings were looked at).
local D

function M.forget()
	D = { move = {}, look = {} }
end
M.forget()

local function dead_zone_of(list)
	for _, mod in ipairs(U.items(list, MAX_MODIFIERS) or {}) do
		if U.class_name(mod) == DEAD_ZONE then return mod end
	end
	return nil
end

local function modifiers(obj)
	local list = nil
	pcall(function() list = obj.Modifiers end)
	return list and dead_zone_of(list)
end

-- The dead zone in place on an action (the action's own, which its live copies take), nil when it cannot be read.
function M.lower(action)
	if not U.is_valid(action) then return nil end
	local mod, cur = modifiers(action), nil
	if mod ~= nil then pcall(function() cur = U.num(mod.LowerThreshold) end) end
	return cur
end

-- The action's own dead zone, looked for again when the action is another object or its dead zone is gone. Without an
-- action, the one last found, so the mod's value can still be given back.
local function own(d, action)
	local addr = U.is_valid(action) and U.address(action) or nil
	if addr ~= nil and (d.action ~= addr or not U.is_valid(d.modifier)) then
		d.action, d.modifier = addr, modifiers(action)
	end
	if U.is_valid(d.modifier) then return d.modifier end
	return nil
end

-- Puts want (nil: the game's value) on one dead zone; the action's own (first) also tells the game's value. Returns true
-- when it wrote.
local function put(d, mod, want, first)
	local cur = nil
	pcall(function() cur = U.num(mod.LowerThreshold) end)
	if cur == nil then return false end
	local mine = d.mine ~= nil and math.abs(cur - d.mine) <= SAME
	if first and not mine then d.game = cur end
	local target = want
	if target == nil then
		if not mine or d.game == nil then return false end
		target = d.game
	end
	if math.abs(cur - target) <= SAME then return false end
	return pcall(function() mod.LowerThreshold = target end)
end

-- Once a stick: a dead zone on the key mapping of a stick action adds to the action's, or stands in for it; the log says
-- so (left as it is). sticks: the action's address -> its stick, for the actions the mod works on.
local function mappings(input, sticks, say)
	local unsaid = {}
	for addr, stick in pairs(sticks) do
		if not D[stick].mapped then unsaid[addr], D[stick].mapped = stick, true end
	end
	if next(unsaid) == nil then return end
	sticks = unsaid
	local list = nil
	pcall(function() list = input.EnhancedActionMappings end)
	for _, mapping in ipairs(U.items(list, MAX_ACTIONS) or {}) do
		local action = nil
		pcall(function() action = mapping.Action end)
		local stick = sticks[U.address(action)]
		local mod = stick and modifiers(mapping)
		if mod ~= nil then
			local v = nil
			pcall(function() v = U.num(mod.LowerThreshold) end)
			say("the key mapping of %s has its own dead zone %s, left as it is", U.name(action) or "?", tostring(v))
		end
	end
end

-- actions: { move = the move action, look = the look action }, nil when not known. wants: { move = a dead zone or nil
-- for the game's, look = ... }. input: the player's input, whose live copies are walked; nil to look at the actions
-- only (the regular check).
function M.apply(actions, wants, input, say)
	-- by_address: the actions whose dead zone the mod works on; known: also those without one, for the mappings' line.
	local by_address, known, written = {}, {}, {}
	for stick, label in pairs(STICKS) do
		local d, action = D[stick], actions and actions[stick]
		local mod = (wants[stick] ~= nil or d.mine ~= nil) and own(d, action) or nil
		written[stick] = { action = false, copies = 0 }
		if mod ~= nil then
			written[stick].action = put(d, mod, wants[stick], true)
			by_address[d.action], known[d.action] = stick, stick
		elseif wants[stick] ~= nil and U.is_valid(action) then
			known[U.address(action)] = stick
			if not d.said then
				d.said = true
				say("%s has no dead zone of its own: the %s keeps the game's", U.name(action) or "?", label)
			end
		end
	end
	if input ~= nil then
		local list = nil
		pcall(function() list = input.ActionInstanceData end)
		for _, inst in ipairs(U.items(list, MAX_ACTIONS) or {}) do
			local source = nil
			pcall(function() source = inst.SourceAction end)
			local stick = by_address[U.address(source)]
			local mod = stick and modifiers(inst)
			if mod ~= nil and put(D[stick], mod, wants[stick], false) then
				written[stick].copies = written[stick].copies + 1
			end
		end
		mappings(input, known, say)
	end
	for stick, label in pairs(STICKS) do
		local d, w = D[stick], written[stick]
		if w.action or w.copies > 0 then
			say("%s dead zone %s (the game's %.2f): %s%d live copies", label,
				wants[stick] and string.format("%.2f", wants[stick]) or "given back", d.game or -1,
				w.action and "the action and " or "", w.copies)
		end
		-- Given back, or nothing left to give back to: the mod holds no dead zone of this stick any more.
		if by_address[d.action] == stick or wants[stick] == nil then d.mine = wants[stick] end
	end
end

function M.holding()
	return D.move.mine ~= nil or D.look.mine ~= nil
end

return M
