-- Enemy attacks and Enemy movement (Kevin, 12 November 2026): the enemies' attacks, and their walk, run, dodges and
-- jumps, each at its own speed from half the game's to three times, bosses included. Their timelines are pushed by the
-- code that pushes the player's (movement_speed.lua, through offer below), their walk held here
-- (movement_enemy_ground.lua), for the monsters of movement_enemy_list.lua. With both at 1, or the mod off, nothing of
-- the enemies is read or kept: the part stops and gives back what it held.

local U = require("movement_unreal")
local Tasks = require("movement_tasks")
local List = require("movement_enemy_list")
local Names = require("movement_enemy_names")
local Ground = require("movement_enemy_ground")

local M = {}

-- The speed of each enemy key, read by movement_speed.lua for the tasks it keeps for this part.
M.rates = { [Names.ATTACKS] = 1, [Names.MOVES] = 1 }

-- At load: whether the game's characters are watched, and the error when not.
M.watch = List.watch

-- A timeline task of another character than the player, offered by movement_speed.lua as the game makes it: what it
-- keeps for an enemy's attack or move whose speed is not the game's ({ task, key, class, ability, fresh, foe }), false
-- to let it go, nil while it cannot be read (offered again next frame).
function M.offer(task, whose, asc)
	local timeline, class = Tasks.is_timeline(task)
	if timeline == nil then return nil end
	if not timeline or List.owner(whose, asc) == nil then return false end
	local ability = nil
	pcall(function() ability = task.Ability end)
	if not U.is_valid(ability) then return false end
	local key = Names.key(ability)
	if key == nil then return nil end
	if not key or M.rates[key] == 1 then return false end
	return { task = task, key = key, class = class, ability = U.address(ability), fresh = true, foe = true }
end

-- rates: { attack, move }, Enemy attacks and Enemy movement, nil while both are the game's or the mod is off. pawn: the
-- player's character. say: the log.
function M.frame(rates, pawn, now, say)
	if rates == nil then
		if List.on() then List.stop() end
		return
	end
	M.rates[Names.ATTACKS], M.rates[Names.MOVES] = rates.attack, rates.move
	if not List.on() then List.start(say, Ground.release, pawn) end
	List.frame(pawn, now)
	Ground.frame(List.all(), rates.move)
end

-- Whether the part runs: while it does, it may hold values on the enemies, and its stop has to run.
M.holding = List.on

-- A new character: the abilities' classes are read anew.
M.forget = Names.forget

-- For the status line: the part's own counts, and the errors met in watching the game's characters.
function M.report()
	local r = List.report()
	local walks, legs = Ground.report()
	local text = "enemies off"
	if List.on() or r.scans > 0 then
		text = string.format("enemies: %d kept, %d near, speed held %d frames, legs %d%s", r.kept, r.near, walks, legs,
			r.left_out > 0 and string.format(", %d left out for want of room", r.left_out) or "")
	end
	return text, r.errors
end

return M
