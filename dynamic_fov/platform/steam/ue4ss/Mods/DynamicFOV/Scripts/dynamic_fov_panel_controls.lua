-- The controller in the panel's life (1.0.5): the panel's input context put on at each opening
-- (dynamic_fov_panel_context.lua), the controller's name read for its icons, the buttons read at each frame of the open
-- panel (dynamic_fov_panel_pad.lua) and made into commands (dynamic_fov_panel_commands.lua), the context looked for once
-- a second and taken off at each closing. Without the context, the panel opens as in 1.0.4, with the keyboard and the
-- mouse only: said once until the reason changes.

local Context = require("dynamic_fov_panel_context")
local Pad = require("dynamic_fov_panel_pad")
local Commands = require("dynamic_fov_panel_commands")
local Names = require("dynamic_fov_panel_pad_names")
local Game = require("dynamic_fov_panel_game")

local M = {}

-- d: report(fmt, ...) and problem(fmt, ...), the panel's lines and its failures.
function M.new(d)
	-- no_context: the last reason given for no context. brand: whose icons, read at the opening.
	local C = { no_context = nil, brand = Names.XBOX }

	-- The input context made and applied, gi the game instance. Returns whether it is on: the open panel's inputs then
	-- go to the game and the panel (dynamic_fov_panel_input.lua).
	function C.take(pc, gi)
		local ok, why = false, "the controller cannot be read"
		if Pad.usable() then ok, why = Context.on(pc, gi) end
		if ok then
			d.report("panel: input context on, %s", why)
		elseif why ~= C.no_context then
			d.problem("panel: no input context (%s): the controller does nothing in the panel", why)
		end
		C.no_context = not ok and why or nil
		return ok
	end

	-- Before the panel's first paint: the controller's name read for its icons, the buttons held then no presses.
	function C.start(pc)
		if not Context.on_now() then return end
		local gamepad = Game.gamepad(pc)
		C.brand = Names.brand_of(gamepad)
		d.report("panel: controller %s, %s icons", gamepad or "unknown", C.brand)
		Commands.start(Pad.start(pc))
	end

	-- At each frame of the open panel, now the clock. Returns the controller's commands (nil when none) and whether a
	-- button the panel uses acted.
	function C.frame(pc, now)
		if not Context.on_now() then return nil, false end
		local down, pressed = Pad.read(pc)
		local c, acted = Commands.take(down, pressed, now)
		local line = Context.frame(pc)
		if line then d.report("panel: %s", line) end
		return c, acted
	end

	-- -1 or 1 while the controller holds left or right, else nil.
	function C.side()
		return Context.on_now() and Commands.side() or nil
	end

	function C.brand_now() return C.brand end

	-- Once a second while the panel is open. Returns a reason to close it, or nil.
	function C.second(pc, gi)
		local line, why = Context.second(pc, gi)
		if line then d.report("panel: %s", line) end
		return why
	end

	-- At each closing.
	function C.off()
		local line = Context.off()
		if line then d.report("panel: %s", line) end
	end

	return C
end

return M
