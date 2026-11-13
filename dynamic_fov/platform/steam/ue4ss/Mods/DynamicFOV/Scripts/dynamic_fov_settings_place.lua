-- Where the view sits (dynamic_fov_settings.lua reads it with the rest): three rows for every situation (1.0.1) and,
-- since 1.0.11, three more for each of five situations, under one switch.

local Values = require("dynamic_fov_values")

local M = {}

-- Distance in % of each mode's own, so the sprint keeps its step back; height and side in cm, side positive to the
-- right (the game's view sits 80 cm right of the character: -80 centres it, CameraProbe pass 4). 0 is the game's
-- view, and no preset changes them.
M.KEYS = {
	{ field = "distance", key = "distance", name = "Distance", min = -50, max = 100, step = 5 },
	{ field = "height", key = "height", name = "Height", min = -100, max = 100, step = 5 },
	{ field = "side", key = "side", name = "Side", min = -200, max = 200, step = 5 },
}
-- A situation's row is added to the row for every situation, 0 leaving the situation as that row sets it (chosen on
-- 7 November 2026: in a menu that cannot copy values, turning the switch on changes nothing until a row moves). The
-- sum stays within the row's own range: the view never goes where the three rows alone could not put it.
M.SWITCH = "PerSituation"
-- field: the situation as dynamic_fov_situations.lua names it.
M.SITUATIONS = {
	{ field = "normal", name = "Normal" },
	{ field = "sprint", name = "Sprint" },
	{ field = "crouch", name = "Crouch" },
	{ field = "combat", name = "Combat" },
	{ field = "lock_on", name = "LockOn" },
}
-- Each situation's three rows, in the file's order: { situation, axis (one of KEYS), name, key }.
M.ROWS = {}
for _, situation in ipairs(M.SITUATIONS) do
	for _, axis in ipairs(M.KEYS) do
		local name = situation.name .. axis.name
		M.ROWS[#M.ROWS + 1] = { situation = situation.field, axis = axis, name = name, key = name:lower() }
	end
end

-- The file's names, in its order.
function M.names()
	local names = {}
	for _, k in ipairs(M.KEYS) do names[#names + 1] = k.name end
	names[#names + 1] = M.SWITCH
	for _, row in ipairs(M.ROWS) do names[#names + 1] = row.name end
	return names
end

-- raw: the file's keys, lowercased. Into s: the three rows, s.per_situation, and s.places[situation][axis].
function M.resolve(raw, s, defaults, warn)
	for _, k in ipairs(M.KEYS) do
		s[k.field] = Values.number(raw, k.key, k.name, defaults[k.field], k.min, k.max, k.step, warn)
	end
	s.per_situation = Values.switch(raw, M.SWITCH:lower(), M.SWITCH, defaults.per_situation, warn)
	s.places = {}
	for _, situation in ipairs(M.SITUATIONS) do s.places[situation.field] = {} end
	for _, row in ipairs(M.ROWS) do
		local axis = row.axis
		s.places[row.situation][axis.field] = Values.number(raw, row.key, row.name, 0, axis.min, axis.max, axis.step,
			warn)
	end
end

-- Into raw, the keys resolve() would read back.
function M.raw(s, raw)
	for _, k in ipairs(M.KEYS) do raw[k.key] = s[k.field] end
	raw[M.SWITCH:lower()] = s.per_situation
	for _, row in ipairs(M.ROWS) do raw[row.key] = s.places[row.situation][row.axis.field] end
end

-- What the camera's layer is asked (dynamic_fov_layer.lua): each situation's place, and, when a situation has a row
-- of its own, the seconds the view takes from one situation to another: the transition time, so the place and the
-- field of view move as one (chosen on 7 November 2026). nil when every situation is the game's: nothing is then
-- asked of the camera.
function M.want(s)
	local by, any, own_rows = {}, false, false
	for _, situation in ipairs(M.SITUATIONS) do
		local place, own = {}, s.places[situation.field]
		for _, k in ipairs(M.KEYS) do
			local added = s.per_situation and own[k.field] or 0
			place[k.field] = math.max(k.min, math.min(k.max, s[k.field] + added))
			any, own_rows = any or place[k.field] ~= 0, own_rows or added ~= 0
		end
		by[situation.field] = place
	end
	if not any then return nil end
	return { by = by, eased = own_rows and s.transition or nil }
end

return M
