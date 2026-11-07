-- Leans the character back during a slide so the lifted back leg comes down (Kevin, 5 November 2026: the back leg is
-- too high, "redresser un peu le personnage"). The slide's animation was made for a 45° downhill: on flat ground the
-- back foot hangs in the air and the front one points into the ground; uphill, both get worse.
-- Only the mesh moves (slide_mesh.lua): the capsule, the movement and the camera's target stay as they are. Every
-- slide leans. A leaning slide turns the game's foot placement off (slide_placement.lua), which otherwise undoes the
-- lean; then the mesh leans back, about the planted foot, by the angle that brings the lifted foot down to the
-- planted one's height (slide_tilt_aim.lua), and moves
-- along the floor's normal so the planted foot and its toe are where the game puts a planted foot (slide_ground.lua,
-- read while running, for the lean the mesh has). The lean goes into the slide as a transition, the move follows the
-- animation closely; both ease back after the slide, then the untilted place is written back exactly.

local R = require("slide_reading")
local Math = require("slide_tilt_math")
local Feet = require("slide_feet")
local Mesh = require("slide_mesh")
local Placement = require("slide_placement")
local Ground = require("slide_ground")
local Aim = require("slide_tilt_aim")
local Log = require("slide_tilt_log")
local Trial = require("slide_trial")

local M = {}

-- 1/s. While a leaning slide runs, the lean follows what it should be as a critically damped spring: it starts
-- without a jolt, speeds up, then slows down as it gets there, 95% of the way in 0.25 s, the default blend time of
-- an Unreal animation montage (not read in this game). Followed within a frame (thirteenth version), the character
-- swung back as fast as the animation lifts the back foot: 0 to 7° at 0.1 s, 43 to 48° at 0.2 s uphill
-- (essai-glissade-18; Kevin: "c'est
-- la transition qui est trop brusque ... ça arrive d'un coup ... en montée ça se voit beaucoup plus"). Followed at
-- 90° a second (ninth version), the back foot stayed up about half a second ("on le voit se redresser").
local LEAN_SPRING = 19
-- How fast the move along the normal follows, and the lean once the slide is over: ease in s, rate in degrees per
-- second at most, rate_up in cm per second at most. While a leaning slide runs, the move follows within about a frame,
-- so the planted foot stays where a planted foot goes whatever the lean. Going back to the untilted place stays
-- slow.
local FOLLOW = { ease = 0.005, rate_up = 1200 }
local BACK = { ease = 0.1, rate = 90, rate_up = 120 }
-- s: the floor's normal the aim is given, eased at the old pace. The game's floor normal turns several degrees from
-- one frame to the next (slope 4.3 a tenth of a second after -1.8 and before -1.0, essai-glissade-14, slide #11),
-- and the move along it follows closely: taken as it came, a 12° turn for one frame shifted the mesh 8.3 cm (fake
-- game, fourteenth version).
local NORMAL_EASE = 0.1
local PIVOT_SPEED = 100           -- cm/s: at most this much of the mesh's move comes from its turning point moving
-- Below both, once the slide is over, the untilted place is written back.
local DONE = 0.05                 -- degrees
local DONE_UP = 0.1               -- cm
-- What a leaning slide turns off: of the two ways the eighth trial tried, only turning off the whole post-process
-- animation worked (slide_placement.lua). Every slide leans (Kevin, 5 November 2026).
local PLAN = "post-process"

-- state: "idle", "on" (a slide runs), "easing" (the slide is over, the lean goes back to nothing).
local T = { mesh = nil, feet = nil, state = "idle", off = false, applied = 0, speed = 0, up = 0, t = 0, want = 0 }

local function put_back(say)
	Placement.release(say)
	if T.last == nil then return end
	if not Mesh.write(T.mesh, T.base.loc, T.base.rot) then say("the mesh's place could not be put back") end
	T.last = nil
end

local function ease(value, target, dt, rate, tau)
	local step = (target - value) * (1 - math.exp(-dt / tau))
	local most = rate * dt
	return value + math.max(-most, math.min(most, step))
end

-- The critically damped spring's exact step over dt toward a target held for that time: the value and its speed.
local function spring(value, speed, target, dt, w)
	local x, e = value - target, math.exp(-w * dt)
	local k = (speed + w * x) * dt
	return target + (x + k) * e, (speed - w * k) * e
end

-- The planted foot the lean turns about, moved no faster than makes the mesh move PIVOT_SPEED at the lean it has:
-- when the planted foot changes while the mesh leans, the mesh must not jump; upright, it follows at once. A slide
-- that started while the one before still leant, the running stride's foot planted, turned about it at once and moved
-- the mesh 9.7 cm in a frame (fake game, fifteenth version).
local function move_pivot(dt)
	local p, to = T.pivot, Aim.front()
	if to == nil then return end
	if p == nil then
		T.pivot = to
		return
	end
	local gap = Math.sub(to, p)
	local far = math.sqrt(Math.dot(gap, gap))
	local most = PIVOT_SPEED * dt / math.max(2 * math.sin(math.rad(T.applied) / 2), 1e-6)
	T.pivot = far <= most and to or Math.toward(p, to, most / far)
end

local function ease_normal(dt, normal)
	if normal == nil or T.n == nil then
		T.n = normal
		return
	end
	T.n = Math.unit(Math.toward(T.n, normal, 1 - math.exp(-dt / NORMAL_EASE)))
end

local function place()
	local tilt = Math.matrix({ p = T.applied, y = 0, r = 0 })
	local pivot = T.pivot or T.base.loc
	local loc = Math.add(Math.apply(Math.sub(T.base.loc, pivot), tilt), pivot)
	local n = Aim.normal()
	if n ~= nil then loc = Math.add(loc, { x = n.x * T.up, y = n.y * T.up, z = n.z * T.up }) end
	return { loc = loc, rot = Math.rotator(Math.mul(T.base.m, tilt)) }
end

local function settled()
	return T.applied < DONE and math.abs(T.up) < DONE_UP
end

local function lean(say)
	if T.last == nil and settled() then return end
	local p = place()
	if T.last ~= nil and Mesh.same(p, T.last) then return end
	if not Mesh.write(T.mesh, p.loc, p.rot) then
		T.off, T.state = true, "idle"
		say("the mesh could not be turned: no tilt from now on")
		put_back(say)
		return
	end
	T.last = p
	if Trial.open() then Log.applied(T.s, T.applied, T.up) end
end

-- Once the player's pawn is ready: its mesh, feet and foot placement. A new mesh may take the writes the old one
-- refused (T.off).
function M.on_pawn(say, pawn)
	T.mesh, T.off = nil, false
	Ground.reset()
	pcall(function() T.mesh = pawn.Mesh end)
	T.feet = R.is_valid(T.mesh) and Feet.find(say, T.mesh) or nil
	if T.feet ~= nil then Placement.on_pawn(say, T.mesh) end
end

-- A slide's plan: what it turns off while it leans, nil once the mesh refused to move (it does not lean), and that
-- in words.
function M.plan()
	local plan = not T.off and PLAN or nil
	return plan, Log.describe(plan)
end

-- A slide starts with its plan (M.plan).
function M.begin(say, n, plan)
	if T.feet == nil or not R.is_valid(T.mesh) then return end
	if T.state == "idle" then
		T.base, T.last, T.applied, T.speed, T.up, T.pivot = Mesh.base(T.mesh), nil, 0, 0, 0, nil
		if T.base == nil then
			say("slide #%d: the mesh's place cannot be read, no tilt", n)
			return
		end
	end
	T.state, T.n, T.t, T.ankle, T.toe = "on", nil, 0, Ground.level()
	T.s = Log.new(n, not T.off and plan or nil, Ground.read())
	Aim.start()
	if T.s.plan ~= nil then Placement.hold(say) end
end

function M.finish(say)
	if T.state ~= "on" then return end
	T.state = "easing"
	if Trial.open() then Log.write(Trial.say, T.s, Aim.foot(T.feet), Placement.text()) end
end

-- Every tick, after the slide's frame. look(): the player's state and the game's floor normal this frame, in the
-- world (nil off the ground), read only when asked.
function M.frame(say, dt, look)
	if T.state == "idle" then return Ground.watch(dt, T.mesh, T.feet, look) end
	if not R.is_valid(T.mesh) then
		T.state = "idle"
		return
	end
	if T.last ~= nil then
		local now = Mesh.adopt(T.mesh, T.base, T.last)
		if now ~= nil then T.last, T.s.rewrites = now, T.s.rewrites + 1 end
	end
	local want, up = 0, 0
	if T.state == "on" then
		local st, normal = look()
		ease_normal(dt, normal)
		want = Aim.measure(T.s, T.mesh, T.feet, T.base, T.n, st.yaw)
	end
	T.want = want
	local pace = (T.state == "on" and T.s.lean) and FOLLOW or BACK
	if pace == FOLLOW then
		T.applied, T.speed = spring(T.applied, T.speed, want, dt, LEAN_SPRING)
	else
		T.applied, T.speed = ease(T.applied, want, dt, BACK.rate, BACK.ease), 0
	end
	if T.state == "on" then
		up = Aim.move(T.s, T.applied, T.ankle, T.toe, T.base.loc)
		T.t = T.t + dt
		if T.s.lean and Trial.open() then Log.curve(T.s, T.t, want, T.applied) end
	end
	T.up = ease(T.up, up, dt, pace.rate_up, pace.ease)
	move_pivot(dt)
	if T.state == "easing" and settled() then
		put_back(say)
		T.state, T.applied, T.speed, T.up = "idle", 0, 0, 0
		return
	end
	Placement.frame()
	lean(say)
	if T.s.lean and T.state == "on" and T.last ~= nil and Trial.open() then Aim.see(T.s, dt, T.mesh, T.feet, T.n) end
end

-- Whether the mesh leans or eases back: a slide's work goes on after the slide.
function M.busy()
	return T.state ~= "idle"
end

-- For the slide's log line: the lean and the lean wanted, the move, then what the aim read.
function M.text()
	return string.format("tilt=%.1f want=%.1f up=%.1f %s", T.applied, T.want, T.up, Aim.text())
end

-- A new pawn, the mod switched off or no button: the mesh and its foot placement get their values back at once.
function M.reset(say)
	if T.state ~= "idle" and R.is_valid(T.mesh) then
		if T.last ~= nil then say("tilt dropped: the old mesh got its place back") end
		put_back(say)
	end
	Placement.reset(say)
	Ground.reset()
	T.state, T.applied, T.speed, T.up, T.mesh, T.feet, T.s, T.last, T.pivot = "idle", 0, 0, 0, nil, nil, nil, nil, nil
end

return M
