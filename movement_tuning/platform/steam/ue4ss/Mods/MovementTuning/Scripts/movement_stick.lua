-- The left stick's cuts, the sticks' dead zones, and the push of the stick read each frame for the curve. The player
-- character's locomotion ability (GA_LocomotionDriver_3DDefault_C, one instance per character) cuts the stick into walk
-- and run, and knows its stick actions and the component that reads the stick (fields of its class, game's type map).
-- The cuts are the only values of the ability the mod writes, on the player's instance only: its class would change
-- every character's.

local U = require("movement_unreal")
local Deadzone = require("movement_deadzone")

local M = {}

local ABILITY = "LocomotionDriver"   -- in the class name of the locomotion ability
local CUTS = { run = "JoystickRunThreshold", walk = "JoystickWalkThreshold", delay = "JoyStickWalkTriggerDelay" }
local CHECK_EVERY = 2     -- seconds between two looks at the actions' dead zones and the cuts: the game can load an action
                          -- again, or give the character a new ability
local MAX_FINDS = 15      -- looks for the ability (one per CHECK_EVERY) before giving up until the next character
local MAX_ABILITIES = 512 -- the player has about 135
local MAX_LINES = 8       -- log lines a character's stick work writes: a game that gave its values back at each check
                          -- would write one every CHECK_EVERY seconds
local SAME = 1e-4         -- the cuts are 32-bit floats

-- By cut, { game, mine } as in movement_deadzone.lua, kept from one character to the next: a character the mod wrote on
-- and taken back later still holds the mod's values, which must not be taken for the game's.
local CUT_SLOTS = { run = {}, walk = {}, delay = {} }

-- ability, component, actions: the ability's instance, its stick reader (nil while not there, false once it cannot be
-- read) and its stick actions. ready: the settings were put in place on the ability. applied: the settings last put in
-- place. dead: the left stick's dead zone in place, for the stick's travel. lines: log lines written for the character.
-- again: the character restarted, whose ability may still hold the mod's cuts, looked for even with the mod off.
local G

function M.forget()
	G = { ability = nil, component = nil, actions = nil, ready = false, applied = false, next_check = 0, finds = 0,
		dead = nil, lines = 0, unwritten = false, again = false }
end
M.forget()

-- The same character again (ClientRestart at the end of a cutscene), or a new one made at its address after a load:
-- the ability is looked for anew, as the old handle may read another object at its address; everything is put in place
-- anew, live copies of the actions included, and the cuts the mod wrote stay known.
function M.restart()
	G.ability, G.component, G.actions, G.ready, G.again = nil, nil, nil, false, true
	G.applied, G.next_check, G.finds = false, 0, 0
end

-- Whether cuts of the mod's may still be on an ability: they are given back once it is found again.
local function owed()
	for _, slot in pairs(CUT_SLOTS) do
		if slot.mine ~= nil then return true end
	end
	return false
end

local function say_capped(say)
	return function(fmt, ...)
		if G.lines >= MAX_LINES then return end
		G.lines = G.lines + 1
		if G.lines == MAX_LINES then fmt = fmt .. " (further stick lines for this character are not written)" end
		say(fmt, ...)
	end
end

local function find(pawn)
	local asc, items = nil, nil
	pcall(function() asc = pawn.AbilitySystemComponent end)
	if not U.is_valid(asc) then return nil end
	pcall(function() items = asc.ActivatableAbilities.Items end)
	for _, spec in ipairs(U.items(items, MAX_ABILITIES) or {}) do
		local ability = nil
		pcall(function() ability = spec.Ability end)
		local name = U.class_name(ability)
		if name ~= nil and name:find(ABILITY, 1, true) then
			for _, list in ipairs({ "NonReplicatedInstances", "ReplicatedInstances" }) do
				local instances = nil
				pcall(function() instances = spec[list] end)
				for _, inst in ipairs(U.items(instances, MAX_ABILITIES) or {}) do
					if U.is_valid(inst) then return inst end
				end
			end
		end
	end
	return nil
end

-- Read again at each check: an action the game loads again is another object.
local function actions(ga)
	local move, look = nil, nil
	pcall(function() move = ga.JoystickMoveInput end)
	pcall(function() look = ga.JoystickLookInput end)
	return { move = move, look = look }
end

local function reader(ga)
	local comp = nil
	pcall(function() comp = ga.LocomotionDriverComponent end)
	return U.is_valid(comp) and comp or nil
end

local function found(ga, say)
	G.ability, G.component, G.ready = ga, reader(ga), false
	local a = actions(ga)
	say("locomotion ability %s: stick actions %s and %s, stick reader %s", U.class_name(ga) or "?",
		U.name(a.move) or "none", U.name(a.look) or "none", G.component and "found" or "not found")
end

-- Puts want (nil: the game's value) on one cut. Returns the values before and after when it wrote; true third when the
-- cut cannot be read or written.
local function cut(slot, ga, field, want)
	local cur = nil
	pcall(function() cur = U.num(ga[field]) end)
	if cur == nil then return nil, nil, true end
	local mine = slot.mine ~= nil and math.abs(cur - slot.mine) <= SAME
	if not mine then slot.game = cur end
	local target = want
	if target == nil and mine then target = slot.game end
	if target == nil or math.abs(cur - target) <= SAME then
		slot.mine = want
		return nil
	end
	if not pcall(function() ga[field] = target end) then return nil, nil, true end
	slot.mine = want
	return cur, target
end

-- All three cuts or none: a run cut left at the game's under a walk cut of the mod's would walk past the run point.
local function cuts(left, say)
	local parts, done = {}, {}
	for key, field in pairs(CUTS) do
		local slot = CUT_SLOTS[key]
		local prev = slot.mine
		local before, after, failed = cut(slot, G.ability, field, left and left[key])
		if failed then
			for _, d in ipairs(done) do
				if pcall(function() G.ability[d.field] = d.before end) then d.slot.mine = d.prev end
			end
			if not G.unwritten then
				G.unwritten = true
				say("the left stick cuts cannot be written: they stay as they were")
			end
			return
		end
		if before ~= nil then
			done[#done + 1] = { slot = slot, field = field, before = before, prev = prev }
			parts[#parts + 1] = string.format("%s %.2f to %.2f", field, before, after)
		end
	end
	if #parts > 0 then
		table.sort(parts)
		say("left stick cuts: %s", table.concat(parts, ", "))
	end
end

-- stick: the stick settings ({ left, right, auto }) when the mod is on, nil to give the game's values back. Returns,
-- when the curve or auto sprint is on and the stick could be read, the push of the left stick (after the dead zone, as
-- the ability reads it) and its travel (before it, as the player pushes it); else nil.
function M.frame(controller, pawn, now, stick, say)
	local left = stick and stick.left
	if stick ~= G.applied or now >= G.next_check then
		local changed = stick ~= G.applied
		-- The cap is for the checks: a change of the settings gets its lines again.
		if changed then G.lines = 0 end
		say = say_capped(say)
		G.next_check = now + CHECK_EVERY
		if not U.is_valid(G.ability) and G.finds < MAX_FINDS and (stick ~= nil or (G.again and owed())) then
			G.finds = G.finds + 1
			local ga = find(pawn)
			if ga ~= nil then
				found(ga, say)
				-- Put in place at the next frame: finding the ability walks all of the player's, the heaviest part of
				-- a load for the mod.
				G.applied, G.next_check = false, now
				return nil
			elseif G.finds == MAX_FINDS then
				say("the locomotion ability cannot be found: the left stick keeps the game's cuts")
			end
		end
		if U.is_valid(G.ability) then
			if G.component ~= false and not U.is_valid(G.component) then G.component = reader(G.ability) end
			G.actions = actions(G.ability)
			cuts(left, say)
		elseif stick == nil and (not G.again or G.finds >= MAX_FINDS) then
			-- Nothing to give the cuts back to: the character the mod wrote them on is gone.
			for _, slot in pairs(CUT_SLOTS) do slot.mine = nil end
		end
		local input = nil
		if changed then pcall(function() input = controller.PlayerInput end) end
		Deadzone.apply(G.actions, { move = left and left.dead, look = stick and stick.right },
			U.is_valid(input) and input or nil, say)
		-- After the dead zones are put in place: the one read is the one the stick goes through.
		G.dead = left and left.dead or (G.actions and Deadzone.lower(G.actions.move))
		G.applied, G.ready = stick, U.is_valid(G.ability)
	end
	-- Checked each frame: UE4SS calls a function on an object by its address, gone or not.
	if (left == nil and not (stick and stick.auto)) or not G.component or not U.is_valid(G.component) then return nil end
	local x, y = nil, nil
	pcall(function()
		local v = G.component:GetCurrentMoveInputRaw()
		x, y = U.num(v.X), U.num(v.Y)
	end)
	if x == nil or y == nil then
		G.component = false
		say("the left stick cannot be read: walking and running keep the game's speeds, and auto sprint is off")
		return nil
	end
	local push = math.sqrt(x * x + y * y)
	-- The game's dead zone is round: push = (travel - dead) / (1 - dead). Unread, the push stands for the travel.
	local dead = G.dead or 0
	return push, push > 0 and dead + push * (1 - dead) or 0
end

-- The player's locomotion ability once the settings are on it, nil before: it holds the sprint action auto sprint
-- presses, and the walk reads its keys a frame after.
function M.ability()
	return G.ready and U.is_valid(G.ability) and G.ability or nil
end

function M.holding()
	return owed() or Deadzone.holding()
end

return M
