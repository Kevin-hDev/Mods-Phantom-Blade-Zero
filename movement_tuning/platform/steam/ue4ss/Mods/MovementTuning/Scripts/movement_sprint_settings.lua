-- The rows under the Sprint heading (movement_settings.lua reads the others, the same tolerant way): Turn off sprint,
-- the high-speed sprint's wait, Sprint mode with auto sprint's stop point and toggle sprint's buttons, Sprint resume and
-- Faster dodge landing.

local V = require("movement_values")
local Buttons = require("movement_buttons")

local M = {}

-- Turn off sprint (movement_sprint_off.lua), in the order Kevin gave (7 November 2026): Sprint turns off both sprints,
-- HighSpeedSprint only the faster one after 2 s of sprint, None leaves both as in the game.
M.SPRINT_OFF = { key = "TurnOffSprint", options = { "Sprint", "HighSpeedSprint", "None" }, default = "None" }
-- The high-speed sprint's wait, the talent's DelayTime (2 s in the game's files): 1 to 8 s (Kevin, 9 November 2026).
M.HIGH_DELAY = { key = "HighSpeedSprintDelay", min = 1, max = 8, step = 0.5, default = 2 }
-- Sprint mode (Kevin, 9 November 2026), one row as the two ways cannot mix: Game, hold the button as in the game; Auto,
-- the left stick pushed all the way starts the sprint, back under the stop point (a percent of the stick's travel)
-- stops it; Toggle, a press of the button picked below starts it, the next stops it. Auto by default: auto sprint was
-- on by default before this row.
M.MODE = { key = "SprintMode", options = { "Game", "Auto", "Toggle" }, default = "Auto" }
-- The row Sprint mode replaced, in files from before 1.0.3: read when SprintMode is missing, on for Auto, off for
-- Game; movement_upgrade.lua replaces it in the file.
M.OLD_AUTO = { key = "AutoSprint", default = true }
M.AUTO_STOP = { key = "AutoSprintStop", min = 20, max = 90, step = 5, default = 50 }
M.TOGGLE_PAD, M.TOGGLE_KEY = Buttons.TOGGLE_PAD, Buttons.TOGGLE_KEY
-- Sprint resume (movement_resume.lua): full speed as soon as the game gives the stick back after a special move; on by
-- default, as the halt it removes is what players asked about.
M.RESUME = { key = "SprintResume", default = true }
-- Faster dodge landing (movement_landing.lua): the end of a dodge on the ground paced to hold the run's speed. A row of
-- its own, on by default, apart from the resume so that each row does what it says (Kevin, 7 November 2026, once the
-- trial of 1.0.9 passed).
M.LANDING = { key = "DodgeLanding", default = true }

local function mode(raw, warn)
	local old = M.OLD_AUTO.key:lower()
	if raw[M.MODE.key:lower()] == nil and raw[old] ~= nil then
		return V.switch(raw, old, M.OLD_AUTO.key, M.OLD_AUTO.default, warn) and "Auto" or "Game"
	end
	return V.choice(raw, M.MODE.key, M.MODE.options, M.MODE.default, warn)
end

local function button(raw, row, warn)
	local name = V.choice(raw, row.key, row.options, row.default, warn)
	return name ~= Buttons.NONE and name or nil
end

-- Fills s: sprint_mode; auto ({ stop }) in mode Auto and toggle ({ pad, key }, nil for None) in mode Toggle, each nil
-- otherwise; high_delay, nil at the game's own; turn_off, sprint_off, high_off; resume; landing.
function M.resolve(raw, warn, s)
	s.sprint_mode = mode(raw, warn)
	if s.sprint_mode == "Auto" then
		s.auto = { stop = V.ranged(raw, M.AUTO_STOP, M.AUTO_STOP.default, warn) / 100 }
	elseif s.sprint_mode == "Toggle" then
		s.toggle = { pad = button(raw, M.TOGGLE_PAD, warn), key = button(raw, M.TOGGLE_KEY, warn) }
	end
	local delay = V.ranged(raw, M.HIGH_DELAY, M.HIGH_DELAY.default, warn)
	s.high_delay = delay ~= M.HIGH_DELAY.default and delay or nil
	s.turn_off = V.choice(raw, M.SPRINT_OFF.key, M.SPRINT_OFF.options, M.SPRINT_OFF.default, warn)
	s.sprint_off, s.high_off = s.turn_off == "Sprint", s.turn_off ~= "None"
	s.resume = V.switch(raw, M.RESUME.key:lower(), M.RESUME.key, M.RESUME.default, warn)
	s.landing = V.switch(raw, M.LANDING.key:lower(), M.LANDING.key, M.LANDING.default, warn)
end

-- Auto and toggle sprint, for the settings line.
function M.describe_mode(s)
	if s.auto ~= nil then return string.format("auto sprint on, stops under %.0f%%", s.auto.stop * 100) end
	if s.toggle ~= nil then
		return string.format("toggle sprint on %s and %s", s.toggle.pad or "no button", s.toggle.key or "no key")
	end
	return "auto sprint off"
end

function M.describe(s)
	return string.format("sprint resume %s; dodge landing %s; turn off sprint %s%s", s.resume and "on" or "off",
		s.landing and "on" or "off", s.turn_off,
		s.high_delay and string.format("; high-speed sprint after %s s", V.show(s.high_delay)) or "")
end

-- Adds the rows' keys and defaults to list, in the menu's order.
function M.entries(list)
	for _, row in ipairs({ M.SPRINT_OFF, M.HIGH_DELAY, M.MODE, M.AUTO_STOP, M.TOGGLE_PAD, M.TOGGLE_KEY, M.RESUME,
		M.LANDING }) do
		list[#list + 1] = { row.key, row.default }
	end
end

return M
