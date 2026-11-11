-- The mods the list shows (D6): those of the catalog the filter lets through, Enabled showing the mods on, Disabled
-- those turned off, both all of them, neither none; a mod without an Enabled switch counts as on. The favourites first,
-- then the others, each in the catalog's order (D178). The chosen mod stays listed while it is chosen, even once it no
-- longer passes (D94): turned off from its own page, it does not vanish under the player. A mod switched from the
-- list stays listed until the panel closes (mod_panel_switches.lua, D183). Worked out again only when the catalog, the
-- filter, the favourites, the mods kept or the chosen mod changed, so a frame makes no table.

local M = {}

-- catalog: the mods read (mod_panel_catalog.lua); state: the panel's state (mod_panel_state.lua), whose switches
-- enabled and disabled are the filter; favorites: mod_panel_favorites.lua.
function M.new(catalog, state, favorites)
	-- shown: the last list made; made_of: what it was made from. stays: the names switched from the list since the
	-- panel opened (at most the mods read), and kept, how many times that set changed.
	local S = { shown = {}, made_of = {}, stays = {}, kept = 0 }

	function S.passes(entry)
		if catalog.off(entry) then return state.get("disabled") == true end
		return state.get("enabled") == true
	end

	-- The mod called name stays listed until S.release.
	function S.stay(name)
		if S.stays[name] then return end
		S.stays[name], S.kept = true, S.kept + 1
	end

	-- At each opening: the mods switched before are filtered again.
	function S.release()
		if next(S.stays) == nil then return end
		S.stays, S.kept = {}, S.kept + 1
	end

	-- The mods shown, keep (a mod's name, or nil) among them while the catalog has it.
	function S.list(keep)
		local all, on, off, fav, m = catalog.list(), state.get("enabled"), state.get("disabled"), favorites.list(),
			S.made_of
		if m.all == all and m.on == on and m.off == off and m.fav == fav and m.keep == keep and m.kept == S.kept then
			return S.shown
		end
		local shown, others = {}, {}
		for _, entry in ipairs(all) do
			if entry.name == keep or S.stays[entry.name] or S.passes(entry) then
				if favorites.is(entry.name) then shown[#shown + 1] = entry else others[#others + 1] = entry end
			end
		end
		table.move(others, 1, #others, #shown + 1, shown)
		S.shown, m.all, m.on, m.off, m.fav, m.keep, m.kept = shown, all, on, off, fav, keep, S.kept
		return shown
	end

	return S
end

return M
