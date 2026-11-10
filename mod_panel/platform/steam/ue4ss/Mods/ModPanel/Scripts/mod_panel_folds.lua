-- The sections folded (D149, D150, D175): every heading folds the rows under it, down to the next heading. A heading
-- starts folded when its author wrote collapsed: true, else open. Where the player folds or opens it otherwise, that is
-- kept in ModPanel.state.json (mod_panel_state.lua), written at a closing, so the section stays as the player left it
-- from one game to the next. A heading is known by its mod's name and its own name among the mod's headings (row.fold,
-- M.ids): a section an author adds above it in an update moves no fold onto another section.

local M = {}

M.MAX_KEPT = 100   -- sections the state file keeps, the last changed first

-- Gives each heading of a mod its name: its English title, with " #2", " #3"... after a title another of the mod's
-- headings already has, so that each is kept on its own.
function M.ids()
	local seen = {}
	return function(title)
		local n = (seen[title] or 0) + 1
		seen[title] = n
		return n == 1 and title or title .. " #" .. n
	end
end

-- state: mod_panel_state.lua's; its "sections" are read here once, and set again at each fold.
function M.new(state)
	-- folded[name][id]: true or false where the player's differs from the author's; nil, the author's.
	-- order: { name, id, folded } of the same, the last changed first, as the state file keeps them.
	-- cache[rows]: { version, list } of the rows shown, made again after any fold.
	local F = { folded = {}, order = {}, cache = setmetatable({}, { __mode = "k" }), version = 0 }

	for _, s in ipairs(state.get("sections")) do
		F.folded[s[1]] = F.folded[s[1]] or {}
		F.folded[s[1]][s[2]] = s[3]
		F.order[#F.order + 1] = { s[1], s[2], s[3] }
	end

	-- The first MAX_KEPT of order, as new tables: the state compares them with those it last wrote.
	local function kept()
		local list = {}
		for i = 1, math.min(#F.order, M.MAX_KEPT) do
			local s = F.order[i]
			list[i] = { s[1], s[2], s[3] }
		end
		return list
	end

	-- Whether heading, a heading row of entry, is folded now.
	function F.is_folded(entry, heading)
		local mine = F.folded[entry.name]
		local v = mine and mine[heading.fold]
		if v == nil then return heading.collapsed == true end
		return v
	end

	-- heading of entry folded (true) or opened (false); whether that changed anything.
	function F.set(entry, heading, folded)
		if heading == nil or heading.type ~= "heading" or heading.fold == nil then return false end
		if F.is_folded(entry, heading) == folded then return false end
		local name, id = entry.name, heading.fold
		for i, s in ipairs(F.order) do
			if s[1] == name and s[2] == id then
				table.remove(F.order, i)
				break
			end
		end
		F.folded[name] = F.folded[name] or {}
		if folded == (heading.collapsed == true) then
			F.folded[name][id] = nil
		else
			F.folded[name][id] = folded
			table.insert(F.order, 1, { name, id, folded })
		end
		F.version = F.version + 1
		state.set("sections", kept())
		return true
	end

	function F.toggle(entry, heading)
		if heading == nil or heading.type ~= "heading" then return false end
		return F.set(entry, heading, not F.is_folded(entry, heading))
	end

	-- The rows of rows (entry's page) outside the folded sections; the same table while nothing folds.
	function F.shown(entry, rows)
		local c = F.cache[rows]
		if c ~= nil and c.version == F.version then return c.list end
		local list, hiding = {}, false
		for _, row in ipairs(rows) do
			if row.type == "heading" then
				hiding = F.is_folded(entry, row)
				list[#list + 1] = row
			elseif not hiding then
				list[#list + 1] = row
			end
		end
		F.cache[rows] = { version = F.version, list = list }
		return list
	end

	return F
end

return M
