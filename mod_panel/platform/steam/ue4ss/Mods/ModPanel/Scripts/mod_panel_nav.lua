-- Where the player is in the open panel: the chosen mod, and either an item of the head of the list
-- (mod_panel_head.lua) or a row among those the chosen mod's page shows. Up and Down move the row and stop at its ends;
-- above the first row they go into the head by its last item, Disabled, and stop at its top, All mods; Down from its
-- last item comes back to the first row (D27, D97). Z and C go to the mod before or after, round the list, the head
-- kept; the pointer chooses the row or the head's item it comes onto and the mod of the entry clicked. A section's
-- title is chosen, to fold or open its section (D150); the rows of a folded section are not in rows_of. The list is the
-- one the filter shows (mod_panel_listing.lua). A move the player could lose sight of asks for a scroll: to the chosen
-- row, to the start of a new mod's rows, to the new mod's entry in the list. That is the Hybrid navigation. Classic
-- (D123, D130) has two levels: the list, where each opening starts, Up and Down going through the head and the mods;
-- the mod's page, entered by Cross, left by Circle or Escape, first row a stop.

local Places = require("mod_panel_places")

local first, place = Places.first, Places.place

local M = {}

-- d: { catalog, listing (mod_panel_listing.lua), rows_of(entry) (the rows a mod's page shows), own (Mod Panel's
-- folder), head (mod_panel_head.lua), classic() (whether the navigation is Classic now) }.
function M.new(d)
	-- mod: the chosen mod's name; row: the chosen row's place in its rows (nil for none); head: the chosen item's place
	-- in the head (nil: a row, or nothing). list: in Classic, the selection is in the list (the head, or the chosen
	-- mod's entry when head is nil), not in the page. scroll: the rows' scroll asked for ("start" or a row),
	-- list_scroll: the list's (an entry).
	local N = { mod = nil, row = nil, head = nil, list = false, scroll = nil, list_scroll = nil }

	local function rows()
		local entry = N.mod and d.catalog.get(N.mod)
		return entry and d.rows_of(entry) or {}
	end

	local function choosable(r, i)
		return i ~= nil and r[i] ~= nil
	end

	local function in_list() return N.list and d.classic() end

	-- The mod at place i of list, from its first row; the head stays chosen.
	local function choose(list, i)
		N.mod = list[i].name
		N.row = first(rows())
		N.scroll, N.list_scroll = "start", i
	end

	-- No mod listed: the selection on Enabled, the box that lists the mods again (D97).
	local function none()
		N.mod, N.row, N.list = nil, nil, d.classic()
		N.head = d.head.place("enabled") or d.head.count()
		if N.head == 0 then N.head = nil end
	end

	-- At each opening, from (the mod of the last opening, or of the state file at the first), else Mod Panel, else the
	-- first mod listed, the selection on its row kept; in Classic, on its entry in the list.
	function N.start(from)
		N.mod = N.mod or from
		local list = d.listing.list(nil)
		local at = N.mod and place(list, N.mod)
		N.head, N.list = nil, d.classic()
		if at == nil then
			at = place(list, d.own) or (#list > 0 and 1 or nil)
			if at == nil then return none() end
			return choose(list, at)
		end
		local r = rows()
		if not choosable(r, N.row) then N.row = first(r) end
		N.scroll, N.list_scroll = N.row or "start", at
	end

	-- Into the head, on its last item.
	local function into_head()
		if d.head.count() > 0 then N.head = d.head.count() end
	end

	-- One step in the head, step: -1 up, 1 down; a stop at its top. Down from its last item: the first mod listed in
	-- Classic's list, else the chosen mod's first row.
	local function head_step(step)
		local list, i = d.listing.list(N.mod), first(rows())
		if step < 0 then
			N.head = math.max(1, N.head - 1)
		elseif N.head < d.head.count() then
			N.head = N.head + 1
		elseif in_list() and #list > 0 then
			N.head = nil
			choose(list, 1)
		elseif not in_list() and i ~= nil then
			N.head, N.row, N.scroll = nil, i, i
		end
	end

	-- One step among the mods of Classic's list: Up from the first one into the head's last item.
	local function list_step(step)
		local list = d.listing.list(N.mod)
		local to = (place(list, N.mod) or 0) + step
		if to < 1 then
			into_head()
		elseif to <= #list then
			choose(list, to)
		end
	end

	-- step: -1 up, 1 down, n times; a stop at the head's top and at the last row. In the page of
	-- the Classic navigation, a stop at the first row too.
	function N.move(step, n)
		for _ = 1, n do
			if N.head ~= nil then
				head_step(step)
			elseif in_list() then
				list_step(step)
			elseif N.row == nil then
				if step < 0 and not d.classic() then into_head() end
			else
				local r, next_row = rows(), N.row + step
				while r[next_row] ~= nil and not choosable(r, next_row) do next_row = next_row + step end
				if r[next_row] ~= nil then
					N.row, N.scroll = next_row, next_row
				elseif step < 0 and not d.classic() then
					into_head()
				end
			end
		end
	end

	-- step: -1 the page's first row it lets choose, its rows from their start; 1 its last, brought into view. From the
	-- head too (D99), and from the list in Classic: into the page.
	function N.edge(step)
		local r, i = rows(), nil
		if step < 0 then
			i = first(r)
		else
			for j = #r, 1, -1 do
				if choosable(r, j) then
					i = j
					break
				end
			end
		end
		if i == nil then return end
		N.head, N.row, N.list, N.scroll = nil, i, false, step < 0 and "start" or i
	end

	-- step: -1 the mod before, 1 the one after, n times, round the list.
	function N.switch(step, n)
		local list = d.listing.list(N.mod)
		if #list == 0 then return end
		local to = ((place(list, N.mod) or 1) - 1 + step * n) % #list + 1
		if list[to].name ~= N.mod then choose(list, to) end
	end

	-- Classic, the chosen mod's entry chosen in the list: Cross enters its page, on the row chosen there before, or
	-- its first. Whether it did: not with a head's item chosen, nor into a page with no row to choose.
	function N.enter()
		if not in_list() or N.head ~= nil then return false end
		local r = rows()
		if first(r) == nil then return false end
		if not choosable(r, N.row) then N.row = first(r) end
		N.list, N.scroll = false, N.row
		return true
	end

	-- Classic, in a mod's page: Circle or Escape come back to the list, on the mod's entry. Whether they did; when not,
	-- they close the panel.
	function N.back()
		if not d.classic() or N.list then return false end
		N.list, N.head = true, nil
		N.list_scroll = place(d.listing.list(N.mod), N.mod)
		return true
	end

	-- The list's order changed (a favourite, D178): the chosen mod's entry brought into view where it now is.
	function N.follow() N.list_scroll = N.mod and place(d.listing.list(N.mod), N.mod) end

	-- The place of the row the commands act on: the chosen row, but none while a head's item or the list is chosen.
	function N.focus()
		if N.head ~= nil or in_list() then return nil end
		return N.row
	end

	-- Whether Circle and Escape come back to the list now, rather than close.
	function N.backs() return d.classic() and not N.list end

	-- The pointer came onto row i: in the page.
	function N.hover(i)
		if (i ~= N.row or N.head or in_list()) and choosable(rows(), i) then N.row, N.head, N.list = i, nil, false end
	end

	-- The pointer came onto the head's item i: in the list, in Classic.
	function N.hover_head(i)
		if i ~= nil and i <= d.head.count() then N.head, N.list = i, d.classic() end
	end

	-- Entry i of the list clicked: in Classic, the selection on that entry, in the list. another: during a wait, where
	-- only another mod's entry acts (D83).
	function N.pick(i, another)
		local list = d.listing.list(N.mod)
		if list[i] == nil or (another and list[i].name == N.mod) then return end
		if list[i].name ~= N.mod then choose(list, i) end
		if d.classic() then N.list, N.head = true, nil end
	end

	-- The filter changed: a chosen mod it no longer lets through gives way to the first mod listed, or to none (D94).
	-- typed: the search changed instead (D186). The chosen mod then stays while the search finds it, as the list keeps
	-- it (D94, D183) even when the filter hides it; with no mod found, none is chosen and the head is left as it is:
	-- the Enabled box of D97 answers an empty filter, and chosen after a typo, a second Enter unchecked it (audit 1.0.4).
	function N.refilter(typed)
		local entry = N.mod and d.catalog.get(N.mod)
		if entry ~= nil and (typed and d.listing.found(entry) or not typed and d.listing.passes(entry)) then return end
		local list = d.listing.list(nil)
		if #list > 0 then return choose(list, 1) end
		if typed then N.mod, N.row = nil, nil else none() end
	end

	function N.rows() return rows() end

	-- The scrolls asked since the last call: the rows' ("start", a row, or nil), then the list's (an entry, or nil).
	function N.take_scroll()
		local rows_to, list_to = N.scroll, N.list_scroll
		N.scroll, N.list_scroll = nil, nil
		return rows_to, list_to
	end

	return N
end

return M
