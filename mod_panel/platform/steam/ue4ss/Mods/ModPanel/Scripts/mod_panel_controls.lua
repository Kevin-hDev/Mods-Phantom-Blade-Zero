-- The controller in the panel's life: its button or its combination pressed (mod_panel_combo.lua, D136), Mod Panel's
-- input context put on in a frame of its own before the panel shows (mod_panel_context.lua, D66), the buttons read at
-- each frame of the open panel, counted (mod_panel_usage.lua) and made into commands (mod_panel_pad_commands.lua), the
-- context looked for once a second and taken off at each closing. Without the context, the panel opens as in 0.2.0,
-- without the controller: said once until the reason changes. While a key or a button is awaited, the panel's button
-- and Circle go to the wait (mod_panel_capture.lua) instead of closing the panel. Circle is a command (escape): the
-- panel closes on it or, in a mod's page of the Classic navigation, comes back to the list (mod_panel_panel.lua).

local Context = require("mod_panel_context")
local Pad = require("mod_panel_pad")
local Stick = require("mod_panel_stick")
local PadCommands = require("mod_panel_pad_commands")
local Keys = require("mod_panel_keys")
local Usage = require("mod_panel_usage")
local Hints = require("mod_panel_hints")
local Icons = require("mod_panel_icons")
local Device = require("mod_panel_device")
local Input = require("mod_panel_input")
local Combo = require("mod_panel_combo")
local PadNames = require("mod_panel_pad_names")

local M = {}

local SLOW_SECOND = 0.002         -- seconds: a slower check of the input context is written
local CROSS, LEFT_CLICK = PadNames.CROSS, "LeftMouseButton"

-- d: pad_button() (the controller's button that opens and closes the panel, or nil when none is read), pad_combo()
-- (the controller's combination, { first, second }, or nil), report(fmt, ...) and problem(fmt, ...) (the panel's lines
-- and its failures).
function M.new(d)
	-- waited: a wait ran at the last frame. slowest: this opening's slowest check of the input context, in seconds.
	local C = { no_context = nil, waited = false, slowest = 0 }
	local merged = {}                 -- the keys' and the controller's commands of a frame with both, used again
	local seen = { buttons = nil, button = false }   -- this frame's buttons pressed (nil: none), the panel's button

	-- Whether the controller's button was pressed during this frame.
	function C.pressed(pc)
		local button = d.pad_button()
		return button ~= nil and Pad.pressed(pc, button)
	end

	-- Whether the controller's combination was just pressed, the panel closed (mod_panel_combo.lua).
	function C.combo(pc)
		local pair = d.pad_combo()
		if pair == nil or not Combo.closed(pc, pair, os.clock()) then return false end
		d.report("panel: the controller's combination pressed")
		return true
	end

	-- The input context made and applied at once, gi the game instance. Returns whether it is on.
	function C.take(pc, gi)
		local ok, why = Context.on(pc, gi)
		if ok then
			d.report("panel: input context on, %s", why)
		elseif why ~= C.no_context then
			d.problem("panel: no input context (%s): the controller does nothing in the panel", why)
		end
		C.no_context = not ok and why or nil
		return ok
	end

	-- Whether the context is on: the open panel's inputs then go to the game and the panel.
	function C.on() return Context.on_now() end

	-- Before the panel's first paint, by_pad when the controller's button opened it: the help shows that device's
	-- commands, the controller's name is read for its icons, and the buttons held then are no presses.
	function C.start(pc, by_pad)
		Device.start(pc)
		Hints.start(by_pad and "pad" or "keys")
		Icons.start(d.report)
		PadCommands.give_way(d.pad_button(), d.pad_combo())
		C.waited = false
		if not Context.on_now() then return end
		Pad.start(pc)
		PadCommands.start(Pad.held())
		Combo.start(Pad.held(), d.pad_combo())
	end

	-- At each frame of the open panel, now the clock, waiting while a wait runs. Returns a reason to close it (the
	-- controller's button or combination), or nil and the controller's commands (nil when none). The panel's button
	-- closes it only when it is no command of the panel (D81): Cross chosen for it still selects, and Circle is escape.
	-- So does the combination, out of a wait (D133).
	function C.frame(pc, now, waiting)
		seen.buttons, seen.button = nil, false
		if not Context.on_now() then return nil, nil end
		local button = d.pad_button()
		local read = nil                  -- the panel's button, read in this frame
		if waiting or not PadCommands.commands(button) then
			read = button ~= nil and Pad.pressed(pc, button)
			if read and not waiting then return "the controller's button", nil end
			seen.button = read
		end
		local pressed = Pad.read(pc, button, read)
		-- With the controller in use, a left click that reached the game is a Cross CommonUI made one, should the
		-- game's view have let go of the mouse (discovery 24, D128); with Cross seen held, the click is not that Cross.
		if Input.pad_mode() and not Pad.held()[CROSS] and Pad.usable() and Pad.pressed(pc, LEFT_CLICK) then
			pressed[#pressed + 1] = CROSS
		end
		Usage.stick(Stick.push())
		for _, name in ipairs(pressed) do Usage.pad(name) end
		if #pressed > 0 then
			seen.buttons = pressed
			Hints.pad()
		end
		-- A wait just ended: what is still held does nothing until let go, as at the opening (audit of 0.4.3). A press
		-- lasts several frames, and the D-pad's right still held would step the row just chosen.
		if C.waited and not waiting then
			PadCommands.start(Pad.held())
			Combo.start(Pad.held(), d.pad_combo())
		end
		C.waited = waiting
		local pair = not waiting and d.pad_combo() or nil
		if pair and not PadCommands.commands(pair[1]) and not PadCommands.commands(pair[2])
			and Combo.open(Pad.held(), pair, now) then
			return "the controller's combination", nil
		end
		local c = PadCommands.take(Pad.held(), pressed, now, button, d.pad_combo())
		local line = Context.frame(pc)
		if line then d.report("panel: %s", line) end
		return nil, c
	end

	-- The buttons pressed in this frame, by engine name, or nil; and whether the panel's button was.
	function C.buttons() return seen.buttons end
	function C.button() return seen.button end

	-- -1 or 1 while the controller holds left or right, else nil.
	function C.side()
		return Context.on_now() and PadCommands.side() or nil
	end

	-- The keys' commands k and the controller's c of a frame, as one (either may be nil).
	function C.merge(k, c)
		if c == nil then return k end
		if k == nil then return c end
		for _, name in ipairs(Keys.COUNTS) do merged[name] = k[name] + c[name] end
		return merged
	end

	-- Once a second while the panel is open. Returns a reason to close it, or nil.
	function C.second(pc, gi)
		local start = os.clock()
		local line, why = Context.second(pc, gi)
		-- Timed: the audit of 0.4.3 thought this check could take 3 to 10 ms, never measured in game. Said once, at the
		-- closing: said at each second, it would fill the log's routine lines in a minute (review of 0.4.4).
		C.slowest = math.max(C.slowest, os.clock() - start)
		if line then d.problem("panel: %s", line) end
		return why
	end

	-- At each closing, and at an opening stopped or refused.
	function C.off()
		if C.slowest > SLOW_SECOND then
			d.report("panel: the input context's check took up to %d ms", math.floor(C.slowest * 1000))
		end
		C.slowest = 0
		local line, failed = Context.off()
		if line then (failed and d.problem or d.report)("panel: %s", line) end
	end

	return C
end

return M
