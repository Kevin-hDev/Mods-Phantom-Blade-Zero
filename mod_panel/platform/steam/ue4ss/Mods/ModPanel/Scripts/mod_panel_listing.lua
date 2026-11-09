-- The mods the list shows (D6): those of the catalog the filter lets through, Enabled showing the mods on, Disabled
-- those turned off, both all of them, neither none; a mod without an Enabled switch counts as on. The chosen mod stays
-- listed while it is chosen, even once it no longer passes (D94): turned off from its own page, it does not vanish
-- under the player. Worked out again only when the catalog, the filter or the chosen mod changed, so a frame makes no
-- table.

local M = {}

-- catalog: the mods read (mod_panel_catalog.lua); state: the panel's state (mod_panel_state.lua), whose switches
-- enabled and disabled are the filter.
function M.new(catalog, state)
	-- shown: the last list made; made_of: what it was made from.
	local S = { shown = {}, made_of = {} }

	function S.passes(entry)
		if catalog.off(entry) then return state.get("disabled") == true end
		return state.get("enabled") == true
	end

	-- The mods shown, in the catalog's order, keep (a mod's name, or nil) among them while the catalog has it.
	function S.list(keep)
		local all, on, off, m = catalog.list(), state.get("enabled"), state.get("disabled"), S.made_of
		if m.all == all and m.on == on and m.off == off and m.keep == keep then return S.shown end
		local shown = {}
		for _, entry in ipairs(all) do
			if entry.name == keep or S.passes(entry) then shown[#shown + 1] = entry end
		end
		S.shown, m.all, m.on, m.off, m.keep = shown, all, on, off, keep
		return shown
	end

	return S
end

return M
