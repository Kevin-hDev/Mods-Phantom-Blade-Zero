-- What an opening does while the panel stays hidden (D38, D49), one step a frame, one slice of BUDGET at most: the
-- engine's functions checked once a session, then whether the player is in play (the game instance found then), then
-- the mods read again, then the panel's frame, then the rows and entries the mods need. The panel shows only once all
-- is done. What a stopped opening did serves the next one: the functions checked, the mods it read, the pieces it made.

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")
local Game = require("mod_panel_game")
local Frame = require("mod_panel_frame")
local Pool = require("mod_panel_pool")

local M = {}

M.BUDGET = 0.003                  -- a slice, in seconds (optimisation.md, 7.1)

-- catalog: the mods read; rows_of(entry): the rows a mod's page shows; max: the darkest backdrop the player may
-- choose, in %; report(line): told which of the game's pieces are in memory (mod_panel_frame.lua); found(gi): told
-- the game instance once found, in a frame of its own, so the panel's language and fonts are set before a build
-- and not in the frame that shows the panel (D38; audit of 0.7.0: 750 engine calls moved out of it).
function M.new(catalog, rows_of, max, report, found)
	-- checked: every engine function as this version knows it. gi: the game instance, found once the player was in
	-- play at this opening; pawn: the character's address then. read: the mods are read again for this opening; asked:
	-- the reserve was told what it must hold; spent: seconds spent reading the mods.
	local O = { checked = false, gi = nil, pawn = nil, read = false, asked = false, spent = 0 }

	local function most_rows()
		local most = 0
		for _, entry in ipairs(catalog.list()) do most = math.max(most, #rows_of(entry)) end
		return most
	end

	-- A new opening, or a stopped one going on.
	function O.begin()
		O.gi, O.pawn, O.asked, O.spent = nil, nil, false, 0
	end

	-- The frame, then the reserve, for every mod read, whatever the filter shows: true once both are whole, false while
	-- some is left, or nil and why.
	local function build()
		if not Frame.alive() then
			local ok, why = Frame.start(O.gi, max, report)
			if not ok then return nil, why end
			return false
		end
		if Frame.get() == nil then
			local done, why = Frame.build_step(M.BUDGET)
			if done == nil then return nil, why end
			return false
		end
		if not O.asked then
			O.asked = true
			Pool.need(most_rows(), #catalog.list())
		end
		return Pool.build_step(M.BUDGET)
	end

	-- One step for the controller pc. Returns true once all is ready, false while some is left, or nil, why, and
	-- whether that is a failure rather than the game's way. Ready or failed, the next opening reads the mods again.
	function O.step(pc)
		if not O.checked then
			local done, why = Calls.check_step(M.BUDGET)
			if done == nil then return nil, why, true end
			O.checked = done
			return false
		end
		if O.gi == nil then
			local playing, pawn, failed = Game.in_play(pc)
			if not playing then return nil, pawn, failed end
			O.gi = Game.instance()
			if O.gi == nil then return nil, "the game instance is not found", true end
			O.pawn = U.address(pawn)
			found(O.gi)
			return false
		end
		if not O.read then
			local start = os.clock()
			O.read = catalog.refresh_step(M.BUDGET)
			O.spent = O.spent + os.clock() - start
			return false
		end
		local done, why = build()
		if done ~= false then O.read = false end
		if done == nil then return nil, "the panel could not be built (" .. tostring(why) .. ")", true end
		return done
	end

	-- The seconds spent reading the mods in this opening.
	function O.spent_reading()
		return O.spent
	end

	return O
end

return M
