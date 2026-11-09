-- All mods, an item of the head of the list (D156 to D158, D163). Off turns off every mod read whose Enabled switch is
-- on, Mod Panel left on, and keeps their names in ModPanel.state.json, written at once, before their files are: a
-- crash between the two leaves names of mods still on, which On then finds on, and nothing is lost. On turns back on
-- only those names, the ones still off, and forgets them. A mod the player turns on himself is forgotten, so an Off of
-- his own later is not undone by On. It acts only once every mod has been read a first time: before, a mod not read
-- yet would be left on and never remembered.

local M = {}

M.ENABLED = "Enabled"

-- The mod's Enabled switch, or nil: a mod without one cannot be turned off in play (D157).
local function switch(entry)
	for _, row in ipairs(entry.rows) do
		if row.key == M.ENABLED and row.type == "toggle" then return row end
	end
	return nil
end

-- d: { catalog, changes (mod_panel_changes.lua), state (mod_panel_state.lua), own (Mod Panel's folder name),
-- report(fmt, ...) for the log }.
function M.new(d)
	local A = {}

	-- Whether All mods is off: names are kept.
	function A.off() return #d.state.get("turned_off") > 0 end

	local function turn_off(now)
		local names = {}
		for _, entry in ipairs(d.catalog.list()) do
			local row = entry.name ~= d.own and switch(entry)
			if row and d.changes.value(entry, row) == true and not d.changes.locked(entry, row) then
				names[#names + 1] = entry.name
			end
		end
		if #names == 0 then
			d.report("All mods: no mod with an Enabled switch is on, nothing turned off")
			return
		end
		d.state.set("turned_off", names)
		if not d.state.save() then
			-- Without the names on the disk, a crash would leave the mods off with nothing to turn them back on.
			d.state.set("turned_off", {})
			d.report("All mods: ModPanel.state.json could not be written, nothing turned off")
			return
		end
		for _, name in ipairs(names) do
			local entry = d.catalog.get(name)
			d.changes.set(entry, switch(entry), false, now)
		end
		d.report("All mods: turned off %s", table.concat(names, ", "))
	end

	-- Forgotten before the mods are turned on; written at the closing, after their files: a crash before leaves names
	-- of mods on, which a second On finds on.
	local function turn_on(now)
		local names = d.state.get("turned_off")
		d.state.set("turned_off", {})
		local back, kept = {}, {}
		for _, name in ipairs(names) do
			local entry = d.catalog.get(name)
			local row = entry and switch(entry)
			if row and d.changes.value(entry, row) == false then
				-- A switch greyed since cannot be set: its mod stays off and its name is kept for a later On.
				if d.changes.locked(entry, row) then
					kept[#kept + 1] = name
				else
					d.changes.set(entry, row, true, now)
					back[#back + 1] = name
				end
			end
		end
		d.state.set("turned_off", kept)
		d.report("All mods: turned back on %s", #back > 0 and table.concat(back, ", ") or "none, all were on or gone")
		if #kept > 0 then d.report("All mods: left off, their switch greyed: %s", table.concat(kept, ", ")) end
	end

	-- Left, Right, Enter, Cross or a click: Off when on, On when off. Whether it acted.
	function A.turn(now)
		if d.catalog.counts() == nil then
			d.report("All mods: the mods are still being read, nothing done")
			return false
		end
		if A.off() then turn_on(now) else turn_off(now) end
		return true
	end

	-- The player turned name on himself: an On later leaves it to him.
	function A.forget(name)
		local names, kept = d.state.get("turned_off"), {}
		for _, n in ipairs(names) do
			if n ~= name then kept[#kept + 1] = n end
		end
		if #kept ~= #names then d.state.set("turned_off", kept) end
	end

	return A
end

return M
