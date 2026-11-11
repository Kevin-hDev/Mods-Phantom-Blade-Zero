-- The On/Off switch on each mod's line of the list (D183): a mod's Enabled switch (mod_panel_all_mods.lua), set as
-- its row in the mod's page sets it (mod_panel_changes.lua), so that a greyed one refuses, the change is written half a
-- second later and All mods hears a mod turned on. Mod Panel's own line has none: turned off, the panel would close and
-- only Mods Menu could turn it back on. A mod switched from the list stays listed until the panel closes, whatever the
-- filter (mod_panel_listing.lua): the list does not move under the player, and a wrong press is undone at once.

local AllMods = require("mod_panel_all_mods")

local M = {}

-- d: { catalog, changes (mod_panel_changes.lua), listing (mod_panel_listing.lua), own (Mod Panel's folder name) }.
function M.new(d)
	local S = {}
	-- Each mod's switch row, false for none, found once per entry: the catalog makes a new entry when it reads a mod
	-- again, and the old one, no longer held, goes (weak keys). The list asks it of every mod at each frame.
	local found = setmetatable({}, { __mode = "k" })

	-- The switch of entry's line, or nil: no Enabled switch, or Mod Panel itself.
	function S.row(entry)
		if entry == nil or entry.name == d.own then return nil end
		local row = found[entry]
		if row == nil then
			row = AllMods.switch(entry) or false
			found[entry] = row
		end
		return row or nil
	end

	-- What entry's line shows: true (on), false (off), or nil (no switch); and whether it is greyed (D148). Off only
	-- when false, as the filter and All mods count a mod turned off (mod_panel_catalog.lua, mod.off).
	function S.look(entry)
		local row = S.row(entry)
		if row == nil then return nil, false end
		return d.changes.value(entry, row) ~= false, d.changes.locked(entry, row) ~= nil
	end

	-- The mod called name turned on (yes true), off (false), or over (nil), at now. Kept listed only once it changed:
	-- a press that changes nothing, or a greyed switch that refuses, leaves the list to its filter.
	function S.set(name, yes, now)
		local entry = d.catalog.get(name)
		local row = S.row(entry)
		if row == nil then return end
		if yes == nil then yes = d.changes.value(entry, row) == false end
		if d.changes.set(entry, row, yes, now) then d.listing.stay(name) end
	end

	return S
end

return M
