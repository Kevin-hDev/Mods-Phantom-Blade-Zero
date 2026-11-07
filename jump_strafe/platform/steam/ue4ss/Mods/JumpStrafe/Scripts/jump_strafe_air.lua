-- The air strafe itself: while the player is in the air, three movement values are ours; on landing, the
-- game's own values go back.
--   AirControl 1 and MaxAcceleration = the grip: Unreal caps the air acceleration at MaxAcceleration, so
--   AirControl alone cannot go past it (measured on 3 November 2026: asking 1500 gave about 700).
--   BrakingFrictionFactor 0 keeps the speed with the stick let go (vanilla falls from 600 to about 210).
-- The game rewrites MaxAcceleration every frame, even in the air (about 100 times per jump), so the values
-- are written every frame while in the air.

local U = require("jump_strafe_unreal")

local M = {}

local EPS = 1e-4
local NOTHING = {}

local owned = {}          -- field name -> { game = its value before ours, written = ours }
local air_values = NOTHING

-- Called when the settings are (re)read.
function M.configure(settings)
	air_values = { AirControl = 1.0, MaxAcceleration = settings.air_accel }
	if settings.keep_momentum then air_values.BrakingFrictionFactor = 0.0 end
end

-- New pawn: its values are its own, nothing of ours to put back.
function M.forget()
	owned = {}
end

-- Whatever does not hold what we wrote last is the game's value: kept to put back on landing.
local function own(cmc, field, want)
	local cur = U.read(cmc, field)
	if cur == nil then return end
	local st = owned[field]
	if st == nil then
		st = {}
		owned[field] = st
	end
	if st.written == nil or math.abs(cur - st.written) >= EPS then st.game = cur end
	if math.abs(cur - want) >= EPS then U.write(cmc, field, want) end
	st.written = want
end

local function give_back(cmc, field, st)
	local cur = U.read(cmc, field)
	if cur ~= nil and st.game ~= nil and math.abs(cur - st.written) < EPS then U.write(cmc, field, st.game) end
	owned[field] = nil
end

-- Called every frame with the falling flag already known. Returns true while the values are ours.
function M.update(cmc, falling)
	local wanted = falling and air_values or NOTHING
	for field, st in pairs(owned) do
		if wanted[field] == nil then give_back(cmc, field, st) end
	end
	if wanted == NOTHING then return false end
	for field, want in pairs(wanted) do own(cmc, field, want) end
	return true
end

return M
