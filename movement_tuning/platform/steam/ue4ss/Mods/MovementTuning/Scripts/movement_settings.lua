-- Movement Tuning's settings, as read from MovementTuning.config.json (the file Mods Menu edits; file handling in
-- movement_file.lua). Tolerant reading: an unknown key is ignored, a missing or wrong value falls back to its default
-- and is reported in UE4SS.log.

local Json = require("movement_json")
local Moves = require("movement_moves")
local Curve = require("movement_curve")
local V = require("movement_values")
local Sprint = require("movement_sprint_settings")

local M = {}

-- Speeds from half the game's (Kevin, 10 November 2026: slower moves for a calmer game, without dragging) to three
-- times. A move can have its own min and max (movement_moves.lua): they bound Global for that move too. Steps of 0.05,
-- asked by a player for finer settings: 0.01 (1 % of speed) cannot be felt and would give each move's list 201 choices.
M.MIN, M.MAX, M.STEP = 0.5, 3.0, 0.05
M.JUMP_MIN = Moves.JUMP_MIN
M.GLOBAL = "Global"               -- a move that follows the Global speed (key AllMoves: its first name, kept for older files)
-- The defaults, for a new settings file and a key missing from one; Jump recovery's is in movement_moves.lua.
M.DEFAULTS = { enabled = true, all = 1.3, attacks = 1.0, jump_height = 1.5 }

-- The sticks: a preset to switch on or a curve of one's own, and the dead zones of both sticks. Left stick Game
-- changes nothing; Smooth is the preset (movement_curve.lua); Custom follows the rows below it. Percents, whole
-- numbers in the file, as the menu shows them.
M.GAME = "Game"
M.LEFT = { M.GAME, "Smooth", "Custom" }
M.LEFT_DEFAULT = "Custom"
-- RunPoint 80: at 90 or 95, the normal run held only between the run point and auto sprint's 99 %, too thin to stay in.
M.STICK = {
	{ key = "LeftDeadZone", field = "dead", min = 0, max = 25, step = 1, default = 4 },
	{ key = "RunPoint", field = "run_point", min = 45, max = 95, step = 1, default = 80 },
	{ key = "SlowestWalk", field = "slowest", min = 30, max = 100, step = 5, default = 30 },
	{ key = "StickCurve", field = "curve", min = 0.5, max = 3, step = 0.05, default = 0.5 },
}
M.RIGHT = { key = "RightDeadZone", min = 0, max = 25, step = 1, default = 3 }
-- The Sprint rows, defined in movement_sprint_settings.lua; here too for make_menu.py, which reads this table.
M.SPRINT_OFF, M.HIGH_DELAY, M.MODE, M.AUTO_STOP = Sprint.SPRINT_OFF, Sprint.HIGH_DELAY, Sprint.MODE, Sprint.AUTO_STOP
M.TOGGLE_PAD, M.TOGGLE_KEY, M.RESUME, M.LANDING = Sprint.TOGGLE_PAD, Sprint.TOGGLE_KEY, Sprint.RESUME, Sprint.LANDING
M.OLD_AUTO = Sprint.OLD_AUTO
-- Realism (Kevin, 9 November 2026: None, Realistic, Hyper realistic): turns, slowdowns and starts, the top speeds left
-- as set (movement_realism.lua). None by default: a player who updates keeps the movement they know.
local NO_REALISM, HYPER = "None", "HyperRealistic"
M.REALISM = { key = "Realism", options = { NO_REALISM, "Realistic", HYPER }, default = NO_REALISM }
-- The enemies (Kevin, 12 November 2026, movement_enemies.lua): their attacks and their movement apart, as Soul's: a
-- player can want fiercer enemies that do not run faster, or the other way. Soul's range; 1 by default, the game's,
-- so that a player who updates keeps the enemies they know.
M.ENEMY_ATTACKS = { key = "EnemyAttacks", min = M.MIN, max = M.MAX, step = M.STEP, default = 1 }
M.ENEMY_MOVEMENT = { key = "EnemyMovement", min = M.MIN, max = M.MAX, step = M.STEP, default = 1 }

-- On the menu's grid: rounded to its step, so 1.35 written by hand and the menu's 1.35 are the same speed.
-- Divided rather than multiplied by the step: 27 / 20 is the 1.35 written in the file, 27 x 0.05 is not.
local function on_grid(n, step)
	return math.floor(n / step + 0.5) / (1 / step)
end

-- A number, or a number in text; nil for anything else.
local function plain(value)
	if type(value) == "string" then value = tonumber(V.trim(value)) end
	if type(value) ~= "number" or value ~= value then return nil end
	return value
end

-- A number or a number in text, from min to max (MIN and MAX when not given), on step (STEP when not given); nil for
-- anything else.
local function speed(value, max, step, min)
	max, min = max or M.MAX, min or M.MIN
	value = plain(value)
	if value == nil or value < min or value > max then return nil end
	return on_grid(value, step or M.STEP)
end

local function number(raw, key, name, default, warn, min)
	local value = raw[key]
	if value == nil then return default end
	local n = speed(value, nil, nil, min)
	if n ~= nil then return n end
	warn(string.format("%s must be %s to %s; using %s", name, V.show(min or M.MIN), V.show(M.MAX), V.show(default)))
	return default
end

-- A move's own speed, or nil when it follows Global. Missing: its default (move.default, nil for Global).
local function move_speed(raw, move, warn)
	local value = raw[move.setting:lower()]
	if value == nil then return move.default end
	if V.word(value) == M.GLOBAL:lower() then return nil end
	local max, min = move.max or M.MAX, move.min or M.MIN
	local n = speed(value, max, move.step, min)
	if n ~= nil then return n end
	-- Over a cap lower than Global's (dodges): the cap, as a file written before the cap was asked for the fastest.
	local raw = plain(value)
	local over = raw ~= nil and raw > max and raw <= M.MAX
	warn(string.format("%s must be %s or %s to %s; using %s", move.setting, M.GLOBAL, V.show(min), V.show(max),
		over and V.show(max) or move.default and V.show(move.default) or M.GLOBAL))
	if over then return max end
	return move.default
end

-- { mode, custom (the Custom rows), left (the curve, nil at Game), right (the right dead zone, nil for the game's) };
-- resolve adds sprint: auto or toggle sprint needs the stick's travel.
local function sticks(raw, warn)
	local st = { mode = V.choice(raw, "LeftStick", M.LEFT, M.LEFT_DEFAULT, warn), custom = {} }
	for _, entry in ipairs(M.STICK) do st.custom[entry.field] = V.ranged(raw, entry, entry.default, warn) end
	local p = st.mode == "Smooth" and Curve.SMOOTH or st.custom
	if st.mode ~= M.GAME then st.left = Curve.left(p.dead, p.run_point, p.slowest, p.curve) end
	local right = raw[M.RIGHT.key:lower()]
	local n = M.RIGHT.default
	if right ~= nil then
		n = V.in_range(right, M.RIGHT)   -- nil for Game too
		if n == nil and V.word(right) ~= M.GAME:lower() then
			warn(string.format("%s must be %s or %d to %d; using %d", M.RIGHT.key, M.GAME, M.RIGHT.min, M.RIGHT.max,
				M.RIGHT.default))
			n = M.RIGHT.default
		end
	end
	if n ~= nil then st.right = n / 100 end
	return st
end

local function all_at_one(rates, list)
	for _, entry in ipairs(list) do
		if rates[entry.key] ~= 1 then return false end
	end
	return true
end

-- raw: the file's keys, lowercased. rates: the speed of each gait, move and of the attacks, by key. ground_neutral,
-- timeline_neutral: walking, running and sprinting, or the moves and attacks, are all at the game's speed, so that part
-- of the mod has nothing to do.
function M.resolve(raw, warn)
	local s = {
		enabled = V.switch(raw, "enabled", "Enabled", M.DEFAULTS.enabled, warn),
		all = number(raw, "allmoves", "AllMoves", M.DEFAULTS.all, warn),
		own = {},
		rates = {},
	}
	for _, move in ipairs(Moves.SPEEDS) do
		s.own[move.key] = move_speed(raw, move, warn)
		s.rates[move.key] = math.max(move.min or M.MIN, math.min(s.own[move.key] or s.all, move.max or M.MAX))
	end
	s.rates[Moves.ATTACKS] = number(raw, "attacks", "Attacks", M.DEFAULTS.attacks, warn)
	-- Not a speed: it does not follow Global.
	s.jump_height = number(raw, "jumpheight", "JumpHeight", M.DEFAULTS.jump_height, warn, M.JUMP_MIN)
	s.ground_neutral = all_at_one(s.rates, Moves.GAITS)
	s.timeline_neutral = all_at_one(s.rates, Moves.MOVES) and s.rates[Moves.ATTACKS] == 1
	s.jump_neutral = s.jump_height == 1
	s.stick = sticks(raw, warn)
	Sprint.resolve(raw, warn, s)
	s.stick.sprint = s.auto ~= nil or s.toggle ~= nil
	-- Auto and toggle sprint read the stick (movement_stick.lua): with either on, the stick part has work to do.
	s.stick_neutral = s.stick.left == nil and s.stick.right == nil and s.auto == nil and s.toggle == nil
	s.realism = V.choice(raw, M.REALISM.key, M.REALISM.options, M.REALISM.default, warn)
	s.realistic, s.hyper = s.realism ~= NO_REALISM, s.realism == HYPER
	s.enemy = { attack = V.ranged(raw, M.ENEMY_ATTACKS, M.ENEMY_ATTACKS.default, warn),
		move = V.ranged(raw, M.ENEMY_MOVEMENT, M.ENEMY_MOVEMENT.default, warn) }
	s.enemy_neutral = s.enemy.attack == 1 and s.enemy.move == 1
	return s
end

local function describe_sticks(s)
	local st = s.stick
	local left = st.mode
	if st.left ~= nil then
		left = string.format("%s (dead zone %.0f%%, run at %.0f%%, slowest walk %.0f%%, curve %s)", st.mode,
			st.left.dead * 100, st.left.run_point * 100, st.left.slowest * 100, V.show(st.left.curve))
	end
	return string.format("left stick %s; right dead zone %s; %s", left,
		st.right and string.format("%.0f%%", st.right * 100) or "game", Sprint.describe_mode(s))
end

function M.describe(s)
	local parts = {}
	for _, move in ipairs(Moves.SPEEDS) do
		parts[#parts + 1] = string.format("%s x%s%s", move.setting, V.show(s.rates[move.key]),
			s.own[move.key] and "" or " (global)")
	end
	return string.format("mod %s, global x%s: %s; attacks x%s; jump height x%s; %s; %s; realism %s; enemy attacks "
		.. "x%s, enemy movement x%s", s.enabled and "on" or "off", V.show(s.all), table.concat(parts, ", "),
		V.show(s.rates[Moves.ATTACKS]), V.show(s.jump_height), describe_sticks(s), Sprint.describe(s), s.realism,
		V.show(s.enemy.attack), V.show(s.enemy.move))
end

-- The file's keys and their defaults, in the menu's order: the moves under the Jump heading (in_jump) come after Jump
-- height.
local function entries()
	local function move_default(move)
		return move.default and V.show(move.default) or M.GLOBAL   -- as the menu writes its choices
	end
	local list = { { "Enabled", M.DEFAULTS.enabled }, { "AllMoves", M.DEFAULTS.all } }
	for _, move in ipairs(Moves.SPEEDS) do
		if not move.in_jump then list[#list + 1] = { move.setting, move_default(move) } end
	end
	list[#list + 1] = { "Attacks", M.DEFAULTS.attacks }
	list[#list + 1] = { "JumpHeight", M.DEFAULTS.jump_height }
	for _, move in ipairs(Moves.SPEEDS) do
		if move.in_jump then list[#list + 1] = { move.setting, move_default(move) } end
	end
	list[#list + 1] = { "LeftStick", M.LEFT_DEFAULT }
	for _, entry in ipairs(M.STICK) do list[#list + 1] = { entry.key, entry.default } end
	list[#list + 1] = { M.RIGHT.key, tostring(M.RIGHT.default) }
	Sprint.entries(list)
	list[#list + 1] = { M.REALISM.key, M.REALISM.default }
	list[#list + 1] = { M.ENEMY_ATTACKS.key, M.ENEMY_ATTACKS.default }
	list[#list + 1] = { M.ENEMY_MOVEMENT.key, M.ENEMY_MOVEMENT.default }
	return list
end

function M.keys()
	local keys = {}
	for i, entry in ipairs(entries()) do keys[i] = entry[1] end
	return keys
end

-- No format number in the file: Mods Menu shows every key of the config as a row. A future format will add one; a file
-- without it is this format.
function M.default_text()
	return Json.encode(entries())
end

return M
