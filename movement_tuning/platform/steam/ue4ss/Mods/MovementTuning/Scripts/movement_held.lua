-- Movement values the mod holds at the game's own times a factor: the braking (movement_brake.lua), the turning grip
-- (movement_grip.lua), the start's acceleration and the body's turn rate (movement_hyper.lua). The game may rewrite
-- them at any frame (it eases them from one gait to the next, verified in game): a value read that is not the one
-- written is the game's new own, and the mod builds on it, never on its own, which would scale it twice. Let go, the
-- game gets its value back where the mod's is still in place.

local U = require("movement_unreal")

local M = {}

-- A value this close to the one written is still the mod's. The engine keeps 32-bit floats, 7 digits: a big value reads
-- back further off (36,000 up to 0.002), and taking the mod's own value for the game's would scale it twice.
local SAME, SAME_PART = 1e-3, 1e-6

local function same(a, b)
	return math.abs(a - b) <= SAME + SAME_PART * math.abs(b)
end

-- A number field of the movement component. A field inside a structure brings its own access, the same two functions.
local FIELD = {
	get = function(cmc, name) return cmc[name] end,
	set = function(cmc, name, v) cmc[name] = v end,
}

-- base, written, access: each field's game value, the value the mod wrote and how it is reached, by name.
function M.new()
	return { base = {}, written = {}, access = {} }
end

local function read(access, cmc, name)
	local ok, v = pcall(access.get, cmc, name)
	return ok and U.num(v) or nil
end

-- The field at the game's value times factor; false when it cannot be read or written. access: nil for a number field
-- of the component, { get(cmc, name), set(cmc, name, value) } for one inside a structure.
function M.hold(h, cmc, name, factor, access)
	access = access or FIELD
	local cur = read(access, cmc, name)
	if cur == nil then return false end
	local written = h.written[name]
	if written == nil or not same(cur, written) then h.base[name] = cur end
	local want = h.base[name] * factor
	if not same(cur, want) and not pcall(access.set, cmc, name, want) then return false end
	h.written[name], h.access[name] = want, access
	return true
end

-- Gives the game its values back where the mod's are still in place, and forgets them.
function M.release(h, cmc)
	if next(h.written) == nil then return end
	if cmc ~= nil then
		for name, written in pairs(h.written) do
			local access = h.access[name]
			local cur = read(access, cmc, name)
			if cur ~= nil and same(cur, written) then pcall(access.set, cmc, name, h.base[name]) end
		end
	end
	h.base, h.written, h.access = {}, {}, {}
end

function M.holding(h)
	return next(h.written) ~= nil
end

return M
