-- The character's gravity scale: the only file that writes it. The game's own moves save the gravity they find and put
-- it back when they end: an air attack sets 5.00, then puts back what it found, often just after the landing (verified
-- in game). When what it found was the mod's raised gravity, the mod's comes back outside any raised jump, and raising
-- it again at the next jump stacked it (2.20, 3.91, 6.93, 12.31). So the mod knows the game's resting gravity and every
-- value it wrote for the character with the gravity it raised it from: a value of its own found outside a raised jump
-- is replaced by that gravity, the one the game's move would have found without the mod, and a jump is always raised
-- from the resting one.

local M = {}

local SAME = 0.001        -- a gravity scale this close to one the mod wrote is the mod's
local MAX_WRITTEN = 16    -- values the mod wrote, remembered for the character: one per jump height used
local STEADY = 1          -- seconds on the ground at one gravity before it counts as the game's resting one: the air
                          -- attack's 5.00 is put back a few hundredths of a second after the landing
local HELD = 30           -- seconds at most a gravity set by a move of the game is not taken for the resting one

local G

-- base: the game's resting gravity, nil until known. candidate, since: a gravity seen on the ground, and since when.
-- written: { value = a gravity the mod wrote, base = the gravity it was raised from }. held_at: when a move of the game
-- last set its own gravity, nil once the resting one is back. last: the gravity seen at the last call.
function M.forget()
	G = { base = nil, candidate = nil, since = nil, written = {}, held_at = nil, last = nil }
end
M.forget()

function M.read(cmc)
	local cur = nil
	pcall(function() cur = tonumber(cmc.GravityScale) end)
	if cur ~= cur then return nil end
	return cur
end

local function entry_of(value)
	if value == nil then return nil end
	for i = #G.written, 1, -1 do
		local w = G.written[i]
		if math.abs(value - w.value) <= SAME then return w end
	end
	return nil
end

function M.is_mod(value)
	return entry_of(value) ~= nil
end

-- Whether the mod has written a gravity for this character: one the game may still put back.
function M.has_written()
	return #G.written > 0
end

-- A move of the game holds its own gravity (cur, found at the end of a raised jump or set in the air): until the resting
-- one is back, what is in place is not learned as the resting gravity. A knock-down can hold it on the ground for more
-- than STEADY (a gravity held 1.2 s was once learned and then given back for good).
function M.held(cur, now)
	if cur == nil or M.is_mod(cur) or (G.base ~= nil and math.abs(cur - G.base) <= SAME) then return end
	G.held_at = now
end

-- Learns the game's resting gravity on the ground: steady for STEADY seconds, not the mod's, not one a move holds.
function M.learn(cur, on_ground, now)
	if not on_ground and G.last ~= nil and cur ~= nil and math.abs(cur - G.last) > SAME then M.held(cur, now) end
	G.last = cur
	if G.held_at ~= nil and (now - G.held_at > HELD or (G.base ~= nil and cur ~= nil
			and math.abs(cur - G.base) <= SAME)) then
		G.held_at = nil
	end
	if not on_ground or cur == nil or cur <= 0 or M.is_mod(cur) or G.held_at ~= nil then
		G.candidate = nil
	elseif G.candidate == nil or math.abs(cur - G.candidate) > SAME then
		G.candidate, G.since = cur, now
	elseif now - G.since >= STEADY then
		G.base = cur
	end
end

-- The gravity a jump is raised from: the game's resting one once known, else the one in place unless it is the mod's.
function M.base(cur)
	if G.base ~= nil then return G.base end
	if cur ~= nil and cur > 0 and not M.is_mod(cur) then return cur end
	return nil
end

-- Writes value, the raised gravity of a jump whose base is base. Returns false when it could not be written.
function M.raise(cmc, base, value)
	if not pcall(function() cmc.GravityScale = value end) then return false end
	if G.base == nil then G.base = base end
	local known = entry_of(value)
	if known ~= nil then
		known.base = base
	else
		if #G.written >= MAX_WRITTEN then table.remove(G.written, 1) end
		G.written[#G.written + 1] = { value = value, base = base }
	end
	return true
end

-- When the gravity in place (cur) is the mod's, gives back the one it was raised from. Returns the gravity given back,
-- or nil when there was nothing to give back.
function M.give_back(cmc, cur)
	local w = entry_of(cur)
	if w == nil then return nil end
	if not pcall(function() cmc.GravityScale = w.base end) then return nil end
	return w.base
end

return M
