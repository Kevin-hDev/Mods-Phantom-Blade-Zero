-- The mods the player made favourites (D178): listed first, each with the game's gold diamond. Kept in the panel's
-- state file by name, as All mods keeps the mods it turned off (mod_panel_state.lua), so a favourite stays one from a
-- game to the next, and a mod removed then put back is one again.

local Folders = require("mod_panel_folders")

local M = {}

local MAX = Folders.MAX_MODS      -- as many as the state file reads

-- state: the panel's state (mod_panel_state.lua), which holds the list as "favorites".
function M.new(state)
	-- of, set: the list the set was made from, and its names as keys. The state's list is replaced as a whole at each
	-- change, so a new list is a new table.
	local F = { of = nil, set = {} }

	local function names()
		local list = state.get("favorites")
		if list ~= F.of then
			F.of, F.set = list, {}
			for _, name in ipairs(list or {}) do F.set[name] = true end
		end
		return F.set
	end

	function F.is(name) return names()[name] == true end

	-- The state's list now: what the list of mods is sorted from (mod_panel_listing.lua).
	function F.list() return state.get("favorites") end

	-- name made a favourite (yes) or no longer one. Whether that changed something.
	function F.set_to(name, yes)
		if name == nil or F.is(name) == yes then return false end
		local list = {}
		for _, n in ipairs(state.get("favorites") or {}) do
			if n ~= name then list[#list + 1] = n end
		end
		if yes then list[#list + 1] = name end
		-- Names of mods no longer there are kept too: past the state file's limit, the oldest goes, not the newest the
		-- file would leave out when read.
		while #list > MAX do table.remove(list, 1) end
		state.set("favorites", list)
		return true
	end

	function F.toggle(name) return F.set_to(name, not F.is(name)) end

	return F
end

return M
