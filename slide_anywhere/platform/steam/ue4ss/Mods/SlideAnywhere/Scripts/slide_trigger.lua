-- When a slide starts, when the player ends it and when it keeps its speed, from the buttons picked in the settings
-- (slide_buttons.lua, none by default). A press while running slides; a second press during the slide ends it (Kevin,
-- 5 November 2026: "en rappuyant sur la touche qui lance le slide il s'arrête"). With the SlideHold setting, the
-- button held keeps the slide's speed (slide_motion.lua). Kevin, the same day: "en un clic notre glissade normale qui
-- s'arrête en fin de vitesse et un nouveau réglage activable où quand on maintient la touche au lieu d'un simple clic,
-- la glissade continue". So a click is the normal slide and a hold the longer one, on the same button; a hold ends
-- when let go (HOLD_TIME, slide_motion.lua).
-- In the air: a press slides at the landing, if it came at most BEFORE s before it ("rond avant le sol"). With
-- SlideHold, a button held counts as pressed until it is let go, pressed before the jump too: a slide cut by a jump,
-- the button still held, slides again at the landing. Such a slide goes at the jump's speed when that is faster than
-- the landing's. On the ground, only a new press slides: held, a slide that ended would start again.
-- Here, nothing of the player is read but the buttons until one is pressed or, with SlideHold, while one is down; then
-- only the movement mode while in the air, and the whole state (look, once per frame) at a press, a take-off or a
-- landing. The lean's readings of the ground at rest are slide_ground.lua's.

local R = require("slide_reading")
local Trial = require("slide_trial")
local Keys = require("slide_keys")
local Slide = require("slide_run")

local M = {}

local BEFORE = 0.3                -- s
local FALLING = 3                 -- EMovementMode

-- down: each button's last read; air: the press waiting for the landing, { t, name, speed }.
local T = { down = {}, air = nil }

-- The buttons held now are not new presses: after a load, a settings change, the mod switched back on.
function M.reset(controller, keys)
	T.down, T.air = {}, nil
	if controller == nil then return end
	Keys.new_frame()
	Keys.hold(controller, keys, T.down)
end

-- The button pressed this frame, or nil; every button's state is read.
local function pressed(controller, keys)
	local name = nil
	for _, key in ipairs(keys) do
		local now = Keys.down(controller, key)
		if now and not T.down[key] then name = name or key end
		T.down[key] = now
	end
	return name
end

-- The first button down, or nil.
local function held(keys)
	for _, key in ipairs(keys) do
		if T.down[key] then return key end
	end
	return nil
end

-- Waiting for the landing: true when the slide started. holding: with SlideHold, a button down, the press going on.
local function landing(say, pawn, now, look, holding)
	local a = T.air
	if holding then a.t = now end
	if now - a.t > BEFORE then
		T.air = nil
		Trial.say("%s in the air: no landing within %.1f s, no slide", a.name, BEFORE)
		return false
	end
	if R.mode(pawn) == FALLING then return false end
	T.air = nil
	return Slide.button(say, now, pawn, look(), a.name .. " before the landing", a.speed)
end

-- Each frame. Returns true when a slide started.
function M.frame(say, controller, pawn, settings, now, look)
	Keys.new_frame()
	local name = pressed(controller, settings.keys)
	local holding = settings.hold and held(settings.keys) or nil
	Slide.hold(holding ~= nil)
	if Slide.running() then
		if name ~= nil then Slide.release("pressed again") end
		return false
	end
	if name == nil and T.air == nil and holding ~= nil then
		if R.mode(pawn) == FALLING then T.air = { t = now, name = holding, speed = look().speed } end
		return false
	end
	if name == nil then
		return T.air ~= nil and landing(say, pawn, now, look, holding ~= nil)
	end
	local s = look()
	if s.mode == FALLING then
		T.air = { t = now, name = name, speed = s.speed }
		return false
	end
	T.air = nil
	return Slide.button(say, now, pawn, s, name)
end

return M
