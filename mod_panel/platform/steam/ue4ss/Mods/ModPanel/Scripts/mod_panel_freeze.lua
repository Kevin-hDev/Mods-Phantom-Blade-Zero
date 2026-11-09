-- The game's pause Mod Panel sets for Freeze game (D8, discovery 8): the only module that touches it. While the panel
-- shows and Freeze game is on (the change waiting included, D93), the game is paused (SetGamePaused); Freeze game off,
-- the pause is lifted at once. At each frame it holds the pause it reads the game's: lifted without it (the game's
-- menu, opened by Options then closed), it does not set it again, and the panel closes (D29): two masters for one pause
-- would fight. Lifted at each closing, on the controller of that frame while it is the one that set it: a load makes
-- another controller and lifts the pause with its world. Only the controller's address is kept, a number: no game
-- object is kept from one frame to the next (optimisation.md, 5.7). A pause the game refuses is said once an opening,
-- the panel open and the game not frozen.
-- The net that does not hang on Mod Panel, should its script stop with the game frozen: Options opens the game's menu,
-- and closing it lifts the pause (discovery 8).

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")
local Game = require("mod_panel_game")

local M = {}

local STATICS = "/Script/Engine.Default__GameplayStatics"

local function set_paused(lib, pc, on) return lib:SetGamePaused(pc, on) end

-- report(fmt, ...) and problem(fmt, ...): the panel's lines and its failures (D104: a failure is written even once the
-- routine lines stopped).
function M.new(report, problem)
	-- addr: the address of the controller the pause was set on, nil while Mod Panel holds none; lib: the engine's
	-- library, found once; refused: the game refused the pause at this opening.
	local F = { addr = nil, lib = nil, refused = false }

	local function library()
		if not U.is_valid(F.lib) then
			local ok, lib = pcall(StaticFindObject, STATICS)
			F.lib = ok and U.is_valid(lib) and lib or nil
		end
		return F.lib
	end

	-- At each opening.
	function F.start() F.refused = false end

	-- Lifts the pause Mod Panel holds, if any, on pc, this frame's controller, while it is the one that set it.
	function F.lift(pc)
		local addr = F.addr
		if addr == nil then return end
		F.addr = nil
		if not U.is_valid(pc) or U.address(pc) ~= addr then return end
		local lib = library()
		local ok, res = false, "the engine's library is not found"
		if lib ~= nil then ok, res = pcall(set_paused, lib, pc, false) end
		if ok and res ~= false then return report("panel: the freeze lifted") end
		problem("panel: the freeze could not be lifted (%s)", ok and "the game refused" or tostring(res))
	end

	-- At each frame of the shown panel, want: whether Freeze game is on. Returns a reason to close the panel, or nil.
	function F.frame(pc, want)
		if F.addr ~= nil then
			-- Freeze game turned off: the pause lifted, the panel left open whatever F.lift returns.
			if not want then
				F.lift(pc)
				return nil
			end
			if Game.paused(pc) == false then
				F.addr = nil
				return "the game lifted the freeze (one of its menus)"
			end
			return nil
		end
		if not want or F.refused or not Calls.ok(Calls.PAUSE) then return nil end
		local lib, addr = library(), U.address(pc)
		local ok, res = false, addr and "the engine's library is not found" or "the controller has no address"
		if lib ~= nil and addr ~= nil then ok, res = pcall(set_paused, lib, pc, true) end
		if ok and res ~= false then
			F.addr = addr
			report("panel: the game frozen")
		else
			F.refused = true
			problem("panel: the game refused to be frozen (%s): it goes on behind the panel", tostring(res))
		end
		return nil
	end

	-- Whether Mod Panel holds the game's pause: then it is no menu of the game's (D95).
	function F.holds() return F.addr ~= nil end

	return F
end

return M
