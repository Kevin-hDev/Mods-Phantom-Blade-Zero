-- The sections folded (D149, D150): every heading folds the rows under it, down to the next heading. A heading starts
-- folded when its author wrote collapsed: true, else open; folded or open, it stays so until the game closes, never
-- written to the disk. A heading is known by its mod's name and its place among the mod's headings (row.fold, set by
-- the descriptor), so a mod read again keeps its sections as the player left them.

local M = {}

function M.new()
	-- folded[name][place]: true or false once the player folded or opened that heading; nil, the author's.
	-- cache[rows]: { version, list } of the rows shown, made again after any fold.
	local F = { folded = {}, cache = setmetatable({}, { __mode = "k" }), version = 0 }

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
		F.folded[entry.name] = F.folded[entry.name] or {}
		F.folded[entry.name][heading.fold] = folded
		F.version = F.version + 1
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
