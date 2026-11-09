-- Each frame's sprint work, in its order: Turn off sprint and the high-speed sprint's wait (movement_sprint_off.lua),
-- the game's walk (movement_walk.lua), toggle sprint's buttons (movement_toggle.lua), then the sprint the mod presses
-- for auto and toggle sprint (movement_sprint.lua).

local Stick = require("movement_stick")
local SprintOff = require("movement_sprint_off")
local Walk = require("movement_walk")
local Toggle = require("movement_toggle")
local Sprint = require("movement_sprint")

local M = {}

function M.forget()
	SprintOff.forget()
	Walk.forget()
	Toggle.forget()
	Sprint.forget()
end

-- s: the settings. stick_on: the stick part works (auto and toggle sprint need the stick's travel). travel: the left
-- stick's, nil when unread.
function M.frame(controller, pawn, s, stick_on, travel, now, log)
	local high_off, sprint_off = s.enabled and s.high_off, s.enabled and s.sprint_off
	local delay = s.enabled and s.high_delay or nil
	local ability = Stick.ability()
	if high_off or delay ~= nil or SprintOff.holding() then
		SprintOff.frame(controller, pawn, ability, high_off, delay, sprint_off, now, log)
	end
	-- With the sprint off, auto and toggle sprint stay off: they press the sprint action itself, past the keys turned
	-- off.
	local on = stick_on and not sprint_off
	local auto, toggle = on and s.auto or nil, on and s.toggle or nil
	local walking = Walk.frame(controller, pawn, ability, now, auto ~= nil or toggle ~= nil, Sprint.active(), log)
	Sprint.frame(ability, travel, auto, Toggle.frame(controller, toggle, travel, walking, now), walking, now, log)
end

-- Sprints started and the game's walk, for the status line.
function M.report()
	return Sprint.report(Toggle.report()) .. ", " .. Walk.report()
end

return M
