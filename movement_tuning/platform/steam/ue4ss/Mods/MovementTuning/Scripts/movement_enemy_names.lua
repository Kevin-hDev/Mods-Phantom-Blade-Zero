-- Which enemy setting an enemy's ability follows: Enemy attacks, Enemy movement, or neither (the game's pace whatever
-- the settings). Families first, where the game has telling ones; names elsewhere: 2,818 of the 4,576 enemy abilities
-- come straight from BP_ActionAbilityBase_Simple_C (type map of build 26266538, single source), so their family says
-- nothing. A timeline that is neither a scene nor a move is an attack or a technique: many bosses' attacks are named
-- without a word for it (Heavy_01, Middle_01, CA_01, Smash, Thrust: 1,444 of the type map's names would have stayed at
-- the game's pace otherwise). EnemyProbe's sorting, tried in game on the 41 enemy abilities it saw (12 November 2026),
-- widened from the type map. Read once per class and kept by the class's address until the next character (forget).

local U = require("movement_unreal")
local Family = require("movement_family")

local M = {}

M.ATTACKS, M.MOVES = "enemy attacks", "enemy moves"

local MAX_CLASSES = 512    -- classes remembered; past this, the memory starts over

-- Executions given and taken, a boss's grab included, and the monsters' lines: filmed scenes.
local GAME_PACE_FAMILIES = { "GA_ExecutionAbilityBase_C", "GA_ExecutedAbilityBase_C", "GA_ExecutionAbilityBase_Grab_C",
	"GA_ExecutedAbilityBase_Grab_C", "GA_ExecutedAbilityBase_Combat_C", "GA_SimpleExecution_Base_C",
	"GA_ContinuousExecutionSimple_Base_C", "PBZ_ShachiWeaponExecutionBase_C", "BP_MonsterSubtitlesBase_C" }
-- Scenes and what is not an action of the enemy's own: executions by name (GEx, GEd, and Gex, Ged in some bosses'),
-- grabs, entrances, a boss's change of phase (SwitchPhase, FinalPhase: Phase1_Atk and the like are attacks), lines,
-- deaths, knockdowns, idles and passives. Hit is no such word: Attack_2Hit, Skill_4Hit are attacks of several hits.
local GAME_PACE_WORDS = { "GEx", "GEd", "Gex", "Ged", "Execution", "Executed", "Grab", "Intro", "Story", "SwitchPhase",
	"FinalPhase", "Subtitles", "Death", "Knock", "Idle", "Passive" }
local ATTACK_FAMILIES = { "GA_AutoComboGroup_C", "BP_ActionAbilityBase_Simple_AllOutAttack_C",
	"GA_WeaponTraceAttack_Base_C", "BP_StanceAction_Base_NPC_C" }
-- Read before the moves' words: an attack that dodges, dashes or jumps (DodgeAttack, JumpBackAttack, Skill_05_Jump,
-- DodgeBackAtk, Combo_02_WithDodgeFrame, in the type map) is an attack (Kevin, 12 November 2026: DodgeAttack goes with
-- the attacks).
local ATTACK_WORDS = { "Attack", "Atk", "Skill", "Combo", "Stance" }
-- Dodges, jumps and the steps aside and back (SpecialMove_L, _R, _B, BackStep, Roll, Teleport), and the walks, runs,
-- turns and slides some enemies play as timelines (Walk_F, Run_Loop, Turn_180, Sliding).
local MOVE_WORDS = { "Dodge", "Dash", "Jump", "Retreat", "SpecialMove", "Step", "Roll", "Teleport", "Walk", "Run",
	"Turn", "Sliding" }

local function set_of(list)
	local set = {}
	for _, name in ipairs(list) do set[name] = true end
	return set
end

local GAME_PACE_SET, ATTACK_SET = set_of(GAME_PACE_FAMILIES), set_of(ATTACK_FAMILIES)

-- keys: class address -> the key, false for the game's pace.
local N = { keys = {}, count = 0 }

local function in_family(names, set)
	for _, name in ipairs(names) do
		if set[name] then return true end
	end
	return false
end

local function has_any(name, words)
	for _, w in ipairs(words) do
		if name:find(w, 1, true) then return true end
	end
	return false
end

-- names: the ability's class name, then the classes it comes from. The key, false for the game's pace.
function M.category(names)
	local name = names[1]
	if type(name) ~= "string" then return false end
	if in_family(names, GAME_PACE_SET) or has_any(name, GAME_PACE_WORDS) then return false end
	if in_family(names, ATTACK_SET) or has_any(name, ATTACK_WORDS) then return M.ATTACKS end
	if has_any(name, MOVE_WORDS) then return M.MOVES end
	return M.ATTACKS
end

-- The key of the setting the ability follows, false for the game's pace, nil when its class cannot be read. ability:
-- just checked valid (GetClass on an object that is not valid crashes the game past any pcall).
function M.key(ability)
	local class = nil
	pcall(function() class = ability:GetClass() end)
	local addr = U.address(class)
	if addr == nil then return nil end
	local key = N.keys[addr]
	if key ~= nil then return key end
	local names = Family.names(class)
	if #names == 0 then return nil end
	key = M.category(names)
	if N.count >= MAX_CLASSES then N.keys, N.count = {}, 0 end
	N.keys[addr], N.count = key, N.count + 1
	return key
end

-- A load can unload a class and put another at its address: the classes are read anew.
function M.forget()
	N.keys, N.count = {}, 0
end

return M
