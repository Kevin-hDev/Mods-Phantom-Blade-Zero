-- A closing of the open panel (D102, audit of 0.4.3): the game gets everything back first, the controls, the freeze,
-- the claim, its input mode and pointer, the panel hidden; then the closing is said; then the files are written, the
-- changes waiting and what the panel keeps. Each step runs under its own guard, an error written and the next step
-- run: before 0.4.4 the files came first, and an error there would have left the game paused, its inputs taken.

local Input = require("mod_panel_input")
local Frame = require("mod_panel_frame")
local Usage = require("mod_panel_usage")

local M = {}

local function hide(problem)
	if not Frame.alive() then return end
	local ok, err = Frame.show(false)
	if not ok then problem("panel: could not be hidden (%s)", tostring(err)) end
end

local function say(said, why)
	said("panel: closed (%s); %s", why, Usage.summary())
end

-- The chosen mod kept for the next opening; with none chosen (a search or a filter that found none), the one kept
-- before stays: a typo then the closing forgot the last mod for good (audit of 1.0.4).
local function keep(state, mod)
	if mod ~= nil then state.set("mod", mod) end
	state.save()
end

-- d: { commands, typing, controls, freeze, claim, nav, edits, state, said(fmt, ...) (the openings' and closings'
-- lines), problem(fmt, ...) }. Returns close(pc, why), for a panel open on pc.
function M.new(d)
	local function guard(what, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then d.problem("panel: %s failed at the closing (%s)", what, tostring(err)) end
	end

	return function(pc, why)
		-- First: while the search field types, a panel key that writes would not open the panel again (D186).
		guard("ending the search", d.typing.close)
		guard("leaving the commands", d.commands.left)
		guard("taking the input context off", d.controls.off)
		guard("lifting the freeze", d.freeze.lift, pc)
		guard("releasing the claim", d.claim.release)
		guard("giving the inputs back", Input.give_back, pc, d.problem)
		guard("hiding the panel", hide, d.problem)
		guard("saying the closing", say, d.said, why)
		guard("writing the changes", d.edits.flush_all, os.clock())
		guard("keeping the panel's state", keep, d.state, d.nav.mod)
	end
end

return M
