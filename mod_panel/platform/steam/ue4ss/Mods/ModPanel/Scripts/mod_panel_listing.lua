-- The mods the list shows (D6): those of the catalog the filter lets through, Enabled showing the mods on, Disabled
-- those turned off, both all of them, neither none; a mod without an Enabled switch counts as on. The favourites first,
-- then the others, each in the catalog's order (D178). The chosen mod stays listed while it is chosen, even once it no
-- longer passes (D94): turned off from its own page, it does not vanish under the player. A mod switched from the
-- list stays listed until the panel closes (mod_panel_switches.lua, D183). The search (mod_panel_search.lua, D186)
-- comes before all that: a mod that does not match is never listed, kept or not; those it finds that the filter hides
-- are counted, for the phrase of an empty list. Worked out again only when the catalog, the filter, the favourites,
-- the mods kept, the chosen mod or the search changed, so a frame makes no table.

local M = {}

-- catalog: the mods read (mod_panel_catalog.lua); state: the panel's state (mod_panel_state.lua), whose switches
-- enabled and disabled are the filter; favorites: mod_panel_favorites.lua; search: mod_panel_search.lua.
function M.new(catalog, state, favorites, search)
	-- shown: the last list made; made_of: what it was made from; hidden: the mods the search found and the filter hid
	-- then. stays: the names switched from the list since the panel opened (at most the mods read), and kept, how many
	-- times that set changed.
	local S = { shown = {}, made_of = {}, hidden_ = 0, stays = {}, kept = 0 }

	local function filtered(entry)
		if catalog.off(entry) then return state.get("disabled") == true end
		return state.get("enabled") == true
	end

	-- Whether entry passes the search and the filter: what a chosen mod must do to stay chosen (D94).
	function S.passes(entry)
		return search.matches(entry) and filtered(entry)
	end

	-- Whether the search finds entry: what a chosen mod must do to stay chosen while the search changes (D186).
	function S.found(entry) return search.matches(entry) end

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

	-- The mods shown, keep (a mod's name, or nil) among them while the catalog has it and the search finds it.
	function S.list(keep)
		local all, on, off, fav, m = catalog.list(), state.get("enabled"), state.get("disabled"), favorites.list(),
			S.made_of
		local query = search.version()
		if m.all == all and m.on == on and m.off == off and m.fav == fav and m.keep == keep and m.kept == S.kept
			and m.query == query then
			return S.shown
		end
		local shown, others, hidden = {}, {}, 0
		for _, entry in ipairs(all) do
			local found = search.matches(entry)
			if found and (entry.name == keep or S.stays[entry.name] or filtered(entry)) then
				if favorites.is(entry.name) then shown[#shown + 1] = entry else others[#others + 1] = entry end
			elseif found then
				hidden = hidden + 1
			end
		end
		table.move(others, 1, #others, #shown + 1, shown)
		S.shown, S.hidden_ = shown, hidden
		m.all, m.on, m.off, m.fav, m.keep, m.kept, m.query = all, on, off, fav, keep, S.kept, query
		return shown
	end

	-- How many mods the search found that the filter hid, at the last list made: 0 without a search.
	function S.hidden() return search.active() and S.hidden_ or 0 end

	return S
end

return M
