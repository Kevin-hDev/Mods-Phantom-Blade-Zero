-- Dynamic FOV's settings as one line of the log (dynamic_fov_settings.lua resolves them).

local Place = require("dynamic_fov_settings_place")

local M = {}

-- The comfort options turned on.
local function comfort_text(s, comfort_keys)
	local on = {}
	for _, k in ipairs(comfort_keys) do
		if s[k.field] then on[#on + 1] = k.log end
	end
	return #on > 0 and table.concat(on, ", ") or "none"
end

-- The situations whose own place is not 0, as added to the three rows.
local function places_text(s)
	if not s.per_situation then return "off" end
	local parts = {}
	for _, situation in ipairs(Place.SITUATIONS) do
		local p = s.places[situation.field]
		if p.distance ~= 0 or p.height ~= 0 or p.side ~= 0 then
			parts[#parts + 1] = string.format("%s %+d%% %+d cm %+d cm", situation.name, p.distance, p.height, p.side)
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or "on, every row at 0"
end

-- s: the settings; comfort_keys: the settings' comfort options; panel_on: whether the mod's own panel can be opened,
-- its backdrop and key said only then. Under a preset, the file's own four values too when they differ, as they are
-- the ones written.
function M.describe(s, comfort_keys, panel_on)
	local text = string.format("mod %s, preset %s, field of view %d, sprint %d, crouch %d, lock-on %d, transition "
		.. "%.1f s, distance %+d%%, height %+d cm, side %+d cm, colours %s, clean image %s%s, comfort: %s, cinematic "
		.. "look %s, position by situation: %s",
		s.enabled and "on" or "off", s.preset, s.normal, s.sprint, s.crouch, s.lock_on, s.transition, s.distance,
		s.height, s.side, s.colours == "Game" and "the game's" or s.colours .. "%", s.clean_image and "on" or "off",
		panel_on and string.format(", panel background %d%%, panel key %s", s.panel_opacity, s.panel_key) or "",
		comfort_text(s, comfort_keys), s.cinematic_look and s.look or "off", places_text(s))
	local c = s.custom
	if c.normal == s.normal and c.sprint == s.sprint and c.crouch == s.crouch and c.lock_on == s.lock_on then
		return text
	end
	return string.format("%s; under Custom: field of view %d, sprint %d, crouch %d, lock-on %d", text, c.normal,
		c.sprint, c.crouch, c.lock_on)
end

return M
