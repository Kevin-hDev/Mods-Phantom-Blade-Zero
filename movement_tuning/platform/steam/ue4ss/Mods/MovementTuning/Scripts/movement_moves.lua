-- Which speed setting a timeline follows, from the family of the ability that plays it: the ability's class and the
-- classes it comes from, as in the game's type map (build 26266538). Families decide first, names only where no family
-- does: names alone misled. GA_Hun_BEx_* are executions without "Execution" in their name,
-- GA_Hun_Young_Jump_C is the young Hun's jump, GA_Hun_BronzeSword_Stance_B_C is a heavy attack.

local M = {}

-- Kept at the game's pace whatever the settings: executions given and taken (filmed scenes, and a faster one would end
-- a boss's grab sooner), perfect dodges (the game slows time itself around one) and held parries (timing windows).
local GAME_PACE = { "GA_ExecutionAbilityBase_C", "GA_ExecutedAbilityBase_C", "GA_ContinuousExecutionSimple_Base_C",
	"BP_PlayerPerfectDodge_Base_C", "BP_HoldDeflect_Base_C" }

-- The dodges' key, read by movement_dodge.lua for their landing.
M.DODGES = "dodges"
-- The jump rows start at the game's own (Kevin, 10 November 2026: they stay as they were), Jump recovery on Global
-- under 1 included; Jump height's row reads it too (movement_settings.lua).
M.JUMP_MIN = 1

-- In order: the first move whose family holds the ability, or whose pattern is in its class name, wins. Patterns stand
-- in for families where the game has none, and keep jumps, weapon draws and stances apart should the families be
-- unreadable.
-- "Sliding" also covers DownSliding and RopeSliding. Ropes, slides and ledges are grouped: only the rope swing was seen
-- in game, and it kept its pace when its timeline ran faster.
M.MOVES = {
	-- The cart fight's special dodges and DodgeAuto are dodges outside the dodge family. max: its speed stops at 2.5,
	-- Global's too: the game chains the next dodge only in the dodge's combo phase, which goes as fast as the rest; at 3
	-- a press at a player's rhythm came after it and the dodge started over.
	{ key = M.DODGES, setting = "Dodges", families = { "BP_PlayerDodge_Base_C" },
		patterns = { "AdvancedDash", "SpecialDash", "SpecialDodge", "DodgeAuto" }, max = 2.5 },
	-- in_jump: shown under the menu's Jump heading, after Jump height, not with the other moves. max: its own speed goes
	-- up to 5: the jump step lasts 0.27 s, 0.09 s at 3, 0.05 s at 5. default: its speed in a new settings file instead
	-- of Global. step: tenths, not the other moves' 0.05: from 1 to 5 that would be 81 choices, for a step a few
	-- hundredths of a second long. min: JUMP_MIN.
	{ key = "jump", setting = "Jump", families = { "BP_Jump_Base_C" }, patterns = { "GA_Hun_Jump", "Young_Jump" },
		in_jump = true, min = M.JUMP_MIN, max = 5, default = 5.0, step = 0.1 },
	{ key = "wall_up", setting = "WallRunUp", patterns = { "UpRunning", "UpRunExecution", "UpRunPole" } },
	{ key = "wall_side", setting = "WallRunSide", patterns = { "SideRunning" } },
	{ key = "ladders", setting = "Ladders", patterns = { "ClimLadder" } },
	{ key = "other", setting = "OtherMoves",
		patterns = { "RopeSwing", "Sliding", "SlopeSlide", "Rappelling", "Mantle", "CrossObstacle", "ThroughHole" } },
	-- Drawing and putting away the weapon (about 1.9 s) and going in and out of a stance: sped up to cut the waits between
	-- actions. Stance's pattern is the name's end: a heavy attack (BronzeSword_Stance_B) and a dodge (StanceDash) carry
	-- the word too; "_Stance_C" names stances only.
	{ key = "weapon_draw", setting = "WeaponDraw", families = { "BP_ChangeArmed_Base_C" }, patterns = { "ChangeArmed" } },
	{ key = "stance", setting = "Stance", families = { "BP_StanceAction_Base_C" }, patterns = { "_Stance_C" } },
}

-- Walking, running and sprinting are not timelines: their speed is the movement component's (movement_ground.lua).
M.GAITS = {
	{ key = "walk", setting = "Walk" },
	{ key = "run", setting = "Run" },
	{ key = "sprint", setting = "Sprint" },
}

-- Every setting that can follow Global: the gaits, then the moves (the menu's order is movement_settings.lua's).
M.SPEEDS = {}
for _, list in ipairs({ M.GAITS, M.MOVES }) do
	for _, entry in ipairs(list) do M.SPEEDS[#M.SPEEDS + 1] = entry end
end

-- A parry or a perfect dodge outside those families keeps the game's pace too: GA_Hun_WoodenSword_PerfectDodge_C comes
-- straight from GameplayAbility, GA_Hun_SnakeDual_A_Deflect_C is a light attack that parries, and a special weapon's
-- GuardPoint is a parry's timing window.
local PARRIES = { "PerfectDodge", "Deflect", "GuardPoint" }
-- Attacks: light, heavy and air attacks, combat arts, switch attacks, the special weapons' abilities and the borrowed
-- weapons' finishers.
local ATTACK_FAMILIES = { "BP_LightAttack_Base_C", "BP_HeavyAttack_Base_C", "BP_LightAttack_Air_Base_C",
	"BP_HeavyAttack_Air_Base_C", "BP_LightAttack_AirLand_Base_C", "BP_CombatArt_Base_C", "BP_SwitchAttack_Base_C",
	"BP_SwitchAttack_SimpleAir_Base_C", "BP_ShachiAbility_Base_C", "BP_TempWeaponUltimate_Base_C" }
-- And, by name, the player's other abilities but those that are not attacks: weapon buffs, drinking, the QTE
-- BDEx_ZuoShang, and executions given and taken. Ex_, Ed_, GEx and GEd count when the families cannot be read: by name
-- alone, 133 executions of the type map would follow Attacks, 4 with them, and no attack is lost.
local ATTACK_PREFIXES = { "GA_Hun_", "BP_SwitchAttack_", "GA_BrutalAxe_" }
local NOT_ATTACKS = { "Execution", "Buff", "BDEx", "Drink", "_BEd_", "Ex_", "Ed_", "GEx", "GEd" }

M.ATTACKS = "attacks"

local function set_of(list)
	local set = {}
	for _, name in ipairs(list or {}) do set[name] = true end
	return set
end

local GAME_PACE_SET, ATTACK_SET = set_of(GAME_PACE), set_of(ATTACK_FAMILIES)
local MOVE_SETS = {}
for i, move in ipairs(M.MOVES) do MOVE_SETS[i] = set_of(move.families) end

local function in_family(names, set)
	for _, name in ipairs(names) do
		if set[name] then return true end
	end
	return false
end

local function has_any(name, patterns)
	for _, p in ipairs(patterns or {}) do
		if name:find(p, 1, true) then return true end
	end
	return false
end

local function starts_with_any(name, prefixes)
	for _, p in ipairs(prefixes) do
		if name:sub(1, #p) == p then return true end
	end
	return false
end

-- names: the ability's class name, then the names of the classes it comes from; a class name alone is read by name
-- only. The key of the setting the ability follows, or nil for one the mod leaves alone.
function M.category(names)
	if type(names) == "string" then names = { names } end
	if type(names) ~= "table" or type(names[1]) ~= "string" then return nil end
	local name = names[1]
	if in_family(names, GAME_PACE_SET) then return nil end
	for i, move in ipairs(M.MOVES) do
		if in_family(names, MOVE_SETS[i]) or has_any(name, move.patterns) then return move.key end
	end
	if has_any(name, PARRIES) then return nil end
	if in_family(names, ATTACK_SET) then return M.ATTACKS end
	if starts_with_any(name, ATTACK_PREFIXES) and not has_any(name, NOT_ATTACKS) then return M.ATTACKS end
	return nil
end

return M
