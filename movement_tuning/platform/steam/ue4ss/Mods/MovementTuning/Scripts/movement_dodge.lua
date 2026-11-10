-- A dodge on the ground, for the sprint resume (movement_resume.lua): whether a dodge held the stick, and, with the
-- faster landing on, the fall that starts its landing, which movement_landing.lua paces. Verified in game (ResumeProbe,
-- 6 November 2026): a dodge on the ground stays in walking mode, its two flips are its montage, which moves the
-- character itself and ignores the stick (no acceleration), and the game takes the stick again the frame the montage
-- ends.
-- While the stick is ignored on the ground, the montage playing is read every LOOK s. The game's dodges seen in game
-- are montages named ..._Dash_...: AM_Hun_Unarm_Dash_F, AM_Hun_Unarm_Dash_BS, AM_Hun_Tang_Dash_F,
-- Hun_TangBlade_Dash_F_Continuous_02_Montage and _03. A dash attack is not a dodge: names with Attack are left out.
-- Other weapons' dodges are expected to follow the same naming (not verified).
-- The landing: each flip ends on a slowing, the speed falling at once under about 500 from over 800, then creeping down
-- to about 100 while the stick stays ignored (0.25 s for the first flip, 0.35 s for the second, at Dodges 1.3).
-- The game chains the next flip from just before the landing (chained flips started 0.44 to 0.54 s in, the landing
-- about 0.47 s): what is left of that window after the landing passes faster too (not verified in game).

local U = require("movement_unreal")
local Moves = require("movement_moves")
local Landing = require("movement_landing")

local M = {}

local WALKING = U.WALKING
local MARK, NOT_A_DODGE = "_Dash_", "Attack"
local LOOK = 0.1   -- seconds between two reads of the montage while the stick is ignored: a dodge holds it 0.26 to
                   -- 1.07 s (seen in game); standing still with the stick let go, a read every LOOK s costs little
local SETTLE = 0.1 -- seconds into a montage before its speed counts: its first frames still carry the dodge before
local TAKEN_WITHIN = 0.2 -- seconds after a dodge's montage ends within which the stick taken again resumes the run:
                         -- the game gives it back the frame the montage ends (a frame later at most, trials of 1.0.7
                         -- and 1.0.8); taken 0.46 s or more later, the character had stopped and was launched from a
                         -- standstill (2 raised to 600, trial of 1.0.8)
-- The speeds below were seen at Dodges 1.3 (trial of 1.0.4); a dodge's speeds go with its pace, so they are compared
-- at the dodge's own.
local MEASURED_AT = 1.3
local FAST = 800 / MEASURED_AT   -- a dodge's speed before its landing: 925 to 1,727 at its top, never under 800
local LANDED = 500 / MEASURED_AT -- the speed the landing falls under at once: 317 to 488, then 548 to 631 for a frame
                                 -- before 300 (the third dodge of a chain); within a dodge, never under 588 once over 800

-- still: the clock since the stick is ignored on the ground, nil while the game takes it. seen: a dodge's montage was
-- read during that time. m, addr, name, since, top: the dodge's montage followed (nil once no dodge plays), its address,
-- its name, when it was first seen and its top speed past SETTLE. over: the clock it was seen ended, nil while one
-- plays. clock, dt: the clock of the last frame and the time since the one before. landing: the faster landing is on.
local G

function M.forget()
	G = { still = nil, seen = false, next_look = 0, m = nil, addr = nil, name = nil, since = 0, top = 0, over = nil,
		clock = nil, dt = nil, landing = false }
	Landing.forget()
end
M.forget()

function M.is_dodge(name)
	return type(name) == "string" and name:find(MARK, 1, true) ~= nil and name:find(NOT_A_DODGE, 1, true) == nil
end

-- Shared with the special moves' resume (movement_resume.lua), whose exit animations hold the stick the same way.
M.LOOK, M.TAKEN_WITHIN = LOOK, TAKEN_WITHIN

local function anim_of(pawn)
	local anim = nil
	pcall(function() anim = pawn.Mesh:GetAnimInstance() end)
	return U.is_valid(anim) and anim or nil
end

-- Whether a montage plays on the character; nil when that cannot be read.
function M.montage_plays(pawn)
	local anim = anim_of(pawn)
	if anim == nil then return nil end
	local m = nil
	pcall(function() m = anim:GetCurrentActiveMontage() end)
	return U.is_valid(m)
end

-- The dodge's montage playing and its address, with its name when it is not the one followed; nil when none plays.
local function dodge_playing(anim)
	local m = nil
	pcall(function() m = anim:GetCurrentActiveMontage() end)
	if not U.is_valid(m) then return nil end
	local addr = U.address(m)
	if addr ~= nil and addr == G.addr then return m, addr end
	local name = U.name(m)
	if not M.is_dodge(name) then return nil end
	return m, addr, name
end

local function speed_of(cmc)
	local s = nil
	pcall(function()
		local v = cmc.Velocity
		local x, y = U.num(v.X), U.num(v.Y)
		if x ~= nil and y ~= nil then s = math.sqrt(x * x + y * y) end
	end)
	return s
end

local function allowed_of(cmc)
	local v = nil
	pcall(function() v = U.num(cmc.MaxWalkSpeed) end)
	return v
end

-- A new montage (a chained dodge) is followed anew; with the faster landing on, the dodge is followed each frame and,
-- from its landing, its speed and the speed allowed are read for its pace. pace: the dodges' setting.
local function follow(pawn, cmc, now, pace, say)
	local anim = anim_of(pawn)
	local m, addr, name = nil, nil, nil
	if anim ~= nil then m, addr, name = dodge_playing(anim) end
	if m == nil then
		Landing.finish(now, say, G.name, G.since, "its montage ended")
		if G.m ~= nil then G.over = now end
		G.m, G.addr = nil, nil
		return
	end
	if addr ~= G.addr then
		Landing.finish(now, say, G.name, G.since, "the next dodge")
		G.m, G.addr, G.name, G.since, G.top, G.over = m, addr, name, now, 0, nil
	end
	if not G.landing or now - G.since < SETTLE then return end
	local speed = speed_of(cmc)
	if Landing.following() then
		Landing.read(speed, allowed_of(cmc))
		return
	end
	if speed == nil then return end
	if speed > G.top then G.top = speed end
	if G.top >= FAST * pace and speed < LANDED * pace then Landing.start(now, speed, allowed_of(cmc)) end
end

-- moving: the game takes the stick this frame (an acceleration). rates: the settings' speeds. landing: the faster
-- landing is on. Returns, on the frame the game takes the stick again after a dodge held it, the clock it was first
-- ignored; nil otherwise, and when the stick comes back more than TAKEN_WITHIN s after the dodge's end. A jump or a
-- special move starts the watch over.
function M.frame(pawn, cmc, mode, moving, now, rates, landing, say)
	G.dt, G.clock = G.clock and now - G.clock, now
	G.landing = landing
	-- Turned off during a landing: that landing is dropped, the dodge back at its pace.
	if not landing then Landing.forget() end
	Landing.settings(rates)
	if mode ~= WALKING then
		Landing.finish(now, say, G.name, G.since, "it left the ground")
		G.still, G.seen, G.m, G.addr, G.over = nil, false, nil, nil, nil
		return nil
	end
	if not moving then
		local pace = rates[Moves.DODGES] or 1
		if G.still == nil then G.still, G.seen, G.next_look = now, false, now end
		-- Each frame while a dodge plays and its landing is paced; otherwise every LOOK s, even once a dodge was seen:
		-- the next dodge of a chain comes a frame after the last one's montage ends.
		if G.m ~= nil and landing then
			follow(pawn, cmc, now, pace, say)
		elseif now >= G.next_look then
			G.next_look = now + LOOK
			follow(pawn, cmc, now, pace, say)
			if G.m ~= nil then G.seen = true end
		end
		return nil
	end
	if Landing.following() then
		Landing.finish(now, say, G.name, G.since, "the stick back", Landing.writes() and speed_of(cmc) or nil)
	end
	local since = G.seen and (G.over == nil or now - G.over <= TAKEN_WITHIN) and G.still or nil
	G.still, G.seen, G.m, G.addr, G.over = nil, false, nil, nil, nil
	return since
end

-- The speeds the player's timelines follow while a dodge plays on the ground with the faster landing on, its landing
-- paced; nil otherwise. Called once a frame, after M.frame.
function M.rates(rates)
	if G.m == nil or not G.landing then return nil end
	return Landing.rates(rates, G.dt)
end

-- Landings paced since the last call, for the status line.
function M.report()
	return Landing.report()
end

return M
