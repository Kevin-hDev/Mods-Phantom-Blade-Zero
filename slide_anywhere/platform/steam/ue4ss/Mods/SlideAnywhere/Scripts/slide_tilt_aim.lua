-- What the tilt (slide_tilt.lua) aims for, frame by frame: the lean that brings the higher foot along the floor's
-- normal down to the lower one's height, and how far the mesh must move along that normal so that the lower foot and
-- its toe are where a planted foot goes (slide_ground.lua). Which foot the slide lifts, told with
-- a lock that waits, only goes to the slide's summary, written by a trial build (slide_tilt_log.lua, slide_trial.lua).
-- Both feet are read every frame of a slide (slide_feet.lua).

local R = require("slide_reading")
local Math = require("slide_tilt_math")
local Feet = require("slide_feet")
local Log = require("slide_tilt_log")
local Trial = require("slide_trial")

local M = {}

-- The lifted foot is brought down to the planted one's height: with half its height kept, Kevin saw it "encore un
-- peu relevée", then "encore un peu trop relevée" (5 November 2026, seventh and eighth trials).
local KEEP = 0
-- Degrees at most. On flat ground the slide's lifted foot wants 20 to 31° (essai-glissade-15). An uphill adds its own
-- slope: on the 24 to 29° uphills of the same trial it wanted more than the 45° allowed then, and the player saw it
-- 12 to 28 cm up on average (Kevin: "en montée ça le fait toujours"). 60 covers uphills up to about 30°.
local MOST = 60
local MIN_LIFT = 8                -- cm: feet closer than this in height are level, none is lifted
-- A foot lifted beside the planted one cannot be brought down by leaning back. The slide's start lifts it before it
-- swings back, and the lean wanted went up to MOST for a few frames (essai-glissade-14: 45° wanted in slides #9, #11
-- and #39, 26 to 33° leaned at the slow pace). So the lean counts in full from FULL_BEHIND cm behind, not at all
-- under NO_BEHIND, in proportion between; the slide's lifted foot is 85 to 96 cm behind (eighth and ninth trials).
local NO_BEHIND, FULL_BEHIND = 30, 60
-- For the summary, the lifted foot may change, but only after the other one has stayed higher this many frames: as
-- the run turns into the slide the feet swap (sixth trial: the first foot found was the running stride's in 5 of 8
-- slides).
local LOCK_FRAMES = 6
-- The slide's animation lifts the right foot: 149 of 149 slides of essai-glissade-12 to -17. A higher left foot is the
-- run's stride still blending into the slide: leaning for it, then for the right one once the feet pass level, turned
-- the character about one foot then the other, and the player saw the legs change sides "comme un changement de garde
-- en boxe" (Kevin, essai-glissade-17, uphill, where the slope's part of the lean comes at once: slide #9 leaned 17°
-- for the left foot at 0.1 s, then 47° for the right one at 0.2 s).
local SLIDE_LIFTS_RIGHT = true
local SEEN_EVERY = 0.1            -- s, how often the lift is read on the feet the player sees
local f = R.f

local A = {}

local function reach(behind)
	return math.max(0, math.min(1, (behind - NO_BEHIND) / (FULL_BEHIND - NO_BEHIND)))
end

-- How steeply the floor rises ahead, in degrees, 0 on flat ground and downhill (n in the actor's space). Leaned back
-- by that much, the character stands on the floor as it does on flat ground.
local function uphill(n)
	return math.max(0, math.deg(math.atan(-n.x, n.z)))
end

function M.start()
	A = { cand_frames = 0, seen_t = 0 }
end

-- Which foot the slide lifts, for the summary; stays nil while none has stayed higher long enough.
local function follow(s, diff)
	if math.abs(diff) < MIN_LIFT then
		A.cand, A.cand_frames = nil, 0
		return
	end
	local high = diff > 0 and "l" or "r"
	if high == A.lock then
		A.cand, A.cand_frames = nil, 0
		return
	end
	if high == A.cand then A.cand_frames = A.cand_frames + 1 else A.cand, A.cand_frames = high, 1 end
	if A.cand_frames < LOCK_FRAMES then return end
	if A.lock ~= nil then Log.switched(s) end
	A.lock, A.cand, A.cand_frames = high, nil, 0
end

-- The move along the normal that puts the planted foot at ankle and its toe, turned by the lean, at least at toe:
-- heights above the mesh's origin. Never below 0: as the slide starts, the lower foot is still in the run's stride,
-- in the air, and planting it pushed the character 6 to 18 cm into the ground for a tenth of a second
-- (essai-glissade-15, slides 5, 9 and 11). Also returns whether the toe decided it.
local function move(front, front_toe, n, lean, ankle, toe, origin)
	local up, by_toe = ankle - Math.dot(Math.sub(front, origin), n), false
	if toe ~= nil and front_toe ~= nil then
		local turned = Math.add(Math.apply(Math.sub(front_toe, front), Math.matrix({ p = lean, y = 0, r = 0 })), front)
		local need = toe - Math.dot(Math.sub(turned, origin), n)
		if need > up then up, by_toe = need, true end
	end
	return math.max(0, up), by_toe
end

-- Returns the lean (degrees) this frame wants, 0 on a slide that does not lean. A frame whose feet cannot be read
-- keeps what the last one read wanted, here and in M.move: going to 0 for it dropped the mesh 16 cm in two frames
-- (fake game, fourteenth version).
function M.measure(s, mesh, feet, base, normal, yaw)
	s.frames, A.lift_now, A.read = s.frames + 1, nil, false
	local l, r, lt, rt = Feet.read(mesh, feet, base)
	if l == nil or normal == nil or yaw == nil then
		s.unread = s.unread + 1
		return A.want or 0
	end
	A.z_l, A.z_r = l.z, r.z
	local n = Math.to_actor(normal, yaw)
	A.n = n
	local summing = Trial.open()
	if summing then follow(s, Math.dot(Math.sub(l, r), n)) end
	-- The lean waits for no lock: the slide's start lifts the back foot in about 0.2 s (essai-glissade-14). When the
	-- feet swap they pass level, where the lean is 0, so it never jumps from one foot to the other.
	A.back_is_r = Math.dot(r, n) > Math.dot(l, n)
	local back, front, front_toe = l, r, rt
	if A.back_is_r then back, front, front_toe = r, l, lt end
	A.front, A.front_toe, A.read = front, front_toe, true
	local d = Math.sub(back, front)
	local lift = Math.dot(d, n)
	A.lift_now = lift
	local full = Math.solve(d, n, lift * KEEP, MOST)
	-- The part that only follows an uphill waits for no foot to swing back: waiting for it left the foot up at the
	-- start (Kevin, essai-glissade-15: "on voit le pied arrière relevé qui descend au début de la glisse").
	local slope = math.min(full, uphill(n))
	local want = slope + (full - slope) * reach(-d.x)
	if A.back_is_r ~= SLIDE_LIFTS_RIGHT then want = 0 end
	if summing and A.lock == (A.back_is_r and "r" or "l") then
		Log.foot(s, lift, d)
		if lift >= MIN_LIFT then Log.want(s, want, lift, -d.x) end
	end
	A.want = s.lean and want or 0
	return A.want
end

-- The move along the normal (cm) for the lean the mesh gets this frame, 0 when the feet were not read this frame or
-- the slide does not lean. ankle, toe: the planted heights above the mesh's origin (slide_ground.lua), toe nil when
-- not known.
function M.move(s, lean, ankle, toe, origin)
	if not A.read then return A.up or 0 end
	local up, by_toe = move(A.front, A.front_toe, A.n, lean, ankle, toe, origin)
	if Trial.open() then Log.up(s, up, by_toe) end
	A.up = s.lean and up or 0
	return A.up
end

-- The planted foot the lean turns about, and the floor's normal, in the actor's space (nil before any reading).
function M.front()
	return A.front
end

function M.normal()
	return A.n
end

-- The lift the player sees (the feet in the world, lean included), next to the untilted one of the same frame.
function M.see(s, dt, mesh, feet, normal)
	A.seen_t = A.seen_t + dt
	if A.seen_t < SEEN_EVERY or (A.lift_now or 0) < MIN_LIFT or normal == nil then return end
	A.seen_t = 0
	local back, front = feet.l, feet.r
	if A.back_is_r then back, front = feet.r, feet.l end
	local b, fr = Feet.world(mesh, back), Feet.world(mesh, front)
	if b ~= nil and fr ~= nil then Log.seen(s, Math.dot(Math.sub(b, fr), normal), A.lift_now) end
end

function M.foot(feet)
	if A.lock == nil then return "none" end
	return A.lock == "l" and feet.l_name or feet.r_name
end

-- For the slide's log line: the lift, and each foot's height in the actor without the lean.
function M.text()
	return string.format("lift=%s feet z=%s/%s", f(A.lift_now), f(A.z_l), f(A.z_r))
end

return M
