-- Higher jumps. The jump from the ground is a physics jump: about 700 up against 2.2 x gravity, 0.65 s in the air
-- (verified in game), and the body's animations are made for that time.
-- At the takeoff of a jump (the frame the character goes from the ground to falling, going up, while a jump ability
-- plays; an enemy's throw is left alone), the vertical speed and the character's gravity are both multiplied, so the
-- jump goes h times as high and lasts t times as long: height = v^2 / 2g and time = 2v / g give v x h / t and
-- g x h / t^2. How long was chosen by eye in game: the same gravity (t = 1.7 at 3) left the character
-- hanging at the top after its animations had ended, gravity x h (t = 1) made it fall too fast; t = 1.3 at 3. Between,
-- t = h^K with 3^K = 1.3 (1.18 at 2).
-- The speed is set through LaunchCharacter with only Z replaced (verified in game): the game's jump does not use
-- CharacterMovement.JumpZVelocity (5 takeoffs at 683 to 688 with 1212 written).
-- A raised jump ends on the ground, in a special move (any mode other than falling), or when something else pushes the
-- character up (an air jump, a hit), so that push gets the game's gravity. A gravity the game sets during the jump is
-- its own move's: left to it. The game's gravity, and the mod's that a move of the game puts back: movement_gravity.lua.

local U = require("movement_unreal")
local Family = require("movement_family")
local Gravity = require("movement_gravity")

local M = {}

local WALKING, FALLING = 1, 3   -- CharacterMovement.MovementMode on the ground and in a jump or a fall
local MAX_REPORTS = 5           -- jumps written to the log for each character
local MAX_NOTES = 5             -- gravities set or put back by the game, written to the log for each character
local MAX_TASKS = 512           -- tasks looked at for a jump ability at a takeoff; the player has about 40
local SAME = 0.001              -- a gravity scale this close to the one written is still the mod's
local PUSHED = 1                -- a vertical speed this much above the last frame's: something pushed the character up
local HOLD_OFF = 30             -- seconds the mod's gravity put back by the game is still replaced once the jump
                                -- height is off: a move of the game holds it while it lasts, a knock-down included
local RECENT = 0.3              -- a jump timeline seen this many seconds before the takeoff still counts: the game's
                                -- jump step lasts 0.27 s, and Jump recovery can end it before the takeoff
local K = math.log(1.3) / math.log(3)   -- time in the air x h^K: 1.3 times as long for 3 times as high

-- The factors of the vertical speed and of the gravity for a jump h times as high.
function M.factors(h)
	local t = h ^ K
	return h / t, h / (t * t)
end

local J
local unwritable_said = false   -- once per session: forget and restart do not clear it

-- raised: during a raised jump, { written = the mod's gravity scale, base = the gravity it was raised from, vz = last
-- vertical speed, report = its number in the log or nil, left = true once the game set its own gravity }. on_at: when
-- the jump height was last on.
function M.forget()
	J = { mode = nil, reports = 0, notes = 0, raised = nil, on_at = nil }
	Gravity.forget()
end
M.forget()

local function note(say, text, ...)
	if J.notes >= MAX_NOTES then return end
	J.notes = J.notes + 1
	say(text, ...)
end

-- A gravity of the mod's that the game put back outside a raised jump: the game's instead. Returns the gravity now in
-- place.
local function guard(cmc, cur, say)
	local given = Gravity.give_back(cmc, cur)
	if given == nil then return cur end
	note(say, "the game put the mod's gravity scale %.2f back: %.2f given back", cur, given)
	return given
end

-- A move of the game that holds its own gravity at the end keeps it: when it puts the mod's back, the guard replaces it.
local function end_jump(cmc, cur, now, why, say)
	local r = J.raised
	J.raised = nil
	if Gravity.give_back(cmc, cur) == nil then Gravity.held(cur, now) end
	if r.report ~= nil then say("jump %d ended (%s), vertical speed %.0f", r.report, why, r.vz) end
end

-- Whether the mod has something to undo on the character: a raised jump, or a gravity of its own that the game may put
-- back (watched while the jump height is on, and for HOLD_OFF seconds after).
function M.holding(now)
	if J.raised ~= nil then return true end
	return Gravity.has_written() and J.on_at ~= nil and now - J.on_at <= HOLD_OFF
end

-- Off or at the game's height: a raised jump gets the game's gravity back, the mod's put back by the game is replaced,
-- and a takeoff is only one seen from the ground after this. cmc: the movement component, nil when not read.
function M.pause(cmc, now, say)
	J.mode = nil
	if cmc == nil or not M.holding(now) then return end
	local cur = Gravity.read(cmc)
	if J.raised ~= nil then return end_jump(cmc, cur, now, "turned off", say) end
	guard(cmc, cur, say)
end

-- The same pawn restarted (the end of a cutscene): a raised jump ends, the gravities the mod wrote stay known.
function M.restart(cmc, now, say)
	if J.raised ~= nil and cmc ~= nil then end_jump(cmc, Gravity.read(cmc), now, "restarted", say) end
	J.raised, J.mode, J.reports, J.notes = nil, nil, 0, 0
end

-- Whether a task of a jump ability is in the player's ability system: looked at on a takeoff only.
local function jump_playing(pawn, say)
	local known = nil
	pcall(function() known = pawn.AbilitySystemComponent.KnownTasks end)
	if known == nil then return false end
	local abilities = {}
	pcall(function()
		known:ForEach(function(_, item)
			if #abilities >= MAX_TASKS then return end
			local task = U.unwrap(item)
			if not U.is_valid(task) then return end
			local ability = nil
			pcall(function() ability = task.Ability end)
			if ability ~= nil then abilities[#abilities + 1] = ability end
		end)
	end)
	for _, ability in ipairs(abilities) do
		if Family.category(ability, say) == "jump" then return true end
	end
	return false
end

local function next_report()
	if J.reports >= MAX_REPORTS then return nil end
	J.reports = J.reports + 1
	return J.reports
end

local function take_off(pawn, cmc, now, vz, cur, height, say, seen_at)
	local recent = seen_at ~= nil and now - seen_at <= RECENT
	if not recent and not jump_playing(pawn, say) then
		local n = next_report()
		if n ~= nil then say("jump takeoff %d: vertical speed %.0f, jump ability not playing, left as is", n, vz) end
		return
	end
	local base = Gravity.base(cur)
	if base == nil then return end
	local speed_factor, gravity_factor = M.factors(height)
	local want = vz * speed_factor
	local written = base * gravity_factor
	-- The gravity first: a jump launched higher without it hangs at its top.
	if not Gravity.raise(cmc, base, written) then
		if not unwritable_said then
			unwritable_said = true
			say("the gravity scale cannot be written: jumps keep the game's height")
		end
		return
	end
	if not pcall(function() pawn:LaunchCharacter({ X = 0, Y = 0, Z = want }, false, true) end) then
		Gravity.give_back(cmc, written)
		return
	end
	local n = next_report()
	J.raised = { written = written, base = base, vz = want, report = n, left = false }
	if n == nil then return end
	if cur ~= nil and math.abs(cur - base) > SAME then
		say("jump takeoff %d: vertical speed %.0f set to %.0f, gravity scale %.2f in place, raised from the game's %.2f "
			.. "to %.2f", n, vz, want, cur, base, written)
	else
		say("jump takeoff %d: vertical speed %.0f set to %.0f, gravity scale %.2f set to %.2f", n, vz, want, base, written)
	end
end

-- During a raised jump: the mod's gravity stays until the jump ends. A gravity the game sets is its own move's: left as
-- it is. An older one of the mod's (another jump height) put back by the game becomes this jump's.
local function keep_raised(cmc, mode, cur, now, say)
	if mode ~= FALLING then return end_jump(cmc, cur, now, mode == WALKING and "landed" or "other move", say) end
	local vz = nil
	pcall(function() vz = U.num(cmc.Velocity.Z) end)
	if vz ~= nil and vz > J.raised.vz + PUSHED then return end_jump(cmc, cur, now, "pushed up", say) end
	if vz ~= nil then J.raised.vz = vz end
	if cur == nil or math.abs(cur - J.raised.written) <= SAME then return end
	if Gravity.is_mod(cur) then
		Gravity.raise(cmc, J.raised.base, J.raised.written)
	elseif not J.raised.left then
		J.raised.left = true
		note(say, "a move of the game set the gravity scale to %.2f during the jump: left to it", cur)
	end
end

-- cmc, mode: the movement component and its MovementMode, read by main.lua. height: how many times as high as the
-- game's jump. seen_at: when the moves' part last saw a jump timeline, or nil.
function M.frame(pawn, cmc, mode, now, height, say, seen_at)
	J.on_at = now
	if cmc == nil then return end
	local was = J.mode
	J.mode = mode
	local cur = Gravity.read(cmc)
	if J.raised ~= nil then return keep_raised(cmc, mode, cur, now, say) end
	Gravity.learn(cur, mode == WALKING, now)
	cur = guard(cmc, cur, say)
	if was ~= WALKING or mode ~= FALLING then return end
	local vz = nil
	pcall(function() vz = U.num(cmc.Velocity.Z) end)
	-- Walking off a ledge also goes from the ground to falling, without going up.
	if vz == nil or vz <= 0 then return end
	take_off(pawn, cmc, now, vz, cur, height, say, seen_at)
end

return M
