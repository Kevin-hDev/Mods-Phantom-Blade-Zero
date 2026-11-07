-- Sprint resume: no halt at the end of a special move (ladder, climb, wall run, rope) or of a dodge on the ground (the
-- dodge's watch: movement_dodge.lua). Verified in game (ResumeProbe, 6
-- November 2026): the game's sprint survives the move or comes back alone, but the game ignores the stick for 0.05 to
-- 0.98 s after the move's end (no acceleration, the speed melts), then the speed climbs at about 1000 a second, as from
-- a standstill: 0.3 to 0.9 s back to a run. At the top of a climb the game itself gives the run speed at once (an
-- acceleration of 10,500 for one frame); the mod does the same after every special move.
-- In the SNAP seconds after the game takes the stick again (its acceleration back above zero), a horizontal speed under
-- the speed allowed (MaxWalkSpeed, the mod's own speeds included) is raised to it, along the game's acceleration: the
-- way the stick points. The game's long sprint (950), dropped during a climb or a rope and only back after 2 s of
-- sprint, is held: while the game sprints, its speed is lifted to the long sprint's (movement_ground.lua writes it)
-- until its own long sprint is back, the sprint ends or HOLD seconds have passed.
-- The time the stick is ignored is the game's exit animation, which moves the character itself and slows it (verified
-- in game, second trial), and is left to the game: stopping the side wall run's roll on landing broke its look and the
-- game still took the stick 0.3 s later (trial of 1.0.3, 6 November 2026, refused by Kevin). The game takes the stick
-- the frame that animation ends (verified for the wall run's roll and the rope, the montages seen in game): a stick
-- taken more than the dodge's TAKEN_WITHIN later had been let go, the character had stopped, and the game starts it
-- from a standstill as it should (a mantle's end in the trial of 1.0.6: stick let go, 1 raised to 348 0.55 s later).

local Tags = require("movement_tags")
local Dodge = require("movement_dodge")

local M = {}

local NONE, WALKING, FALLING = 0, 1, 3   -- CharacterMovement.MovementMode; special moves run in other modes (5)
local WAIT = 1.5       -- seconds after a move's end the stick is waited for: the longest seen, 0.98 s (side wall run)
local SNAP = 0.3       -- seconds after the stick is taken again that the speed is raised: the game's sprint comes back
                       -- up to 0.15 s after it, and the long sprint's hold lifts the speed the frame after
local HOLD = 3         -- seconds the long sprint is held at most: the game brings its own back after 2 s of sprint
local MARGIN = 25      -- a speed this far under the one allowed is raised
local MOVING = 1       -- an acceleration above this: the game takes the stick
local SAME = 0.5
local MAX_REPORTS = 5  -- resumes written to the log for each character
local REPORTED = 100   -- a raise this big at least is written: the top of a climb gives five of 25, which took the
                       -- five lines in game (6 November 2026)

-- special: in a special move. long: the game's speed before it, when that was over the sprint's (the long sprint).
-- ended: the clock at the move's end (for a dodge, when it first ignored the stick). free: the clock its exit animation
-- was first seen over, nil before; look: the clock of the next look at it. taken: the clock when the game took the
-- stick again; counted, told: that resume counted and written. kind: what held it, for the log. floor: the long sprint
-- held, { speed, till }. reports: resumes written. resumes, holds: for the status line, kept across characters.
local G

function M.forget()
	G = { special = false, last_game = nil, long = nil, ended = nil, free = nil, look = 0, taken = nil, counted = false,
		told = false, kind = nil, floor = nil, reports = 0, resumes = G and G.resumes or 0, holds = G and G.holds or 0 }
	Dodge.forget()
end
M.forget()

local function special(mode)
	return mode ~= nil and mode ~= NONE and mode ~= WALKING and mode ~= FALLING
end

local function flat(v)
	local x, y = nil, nil
	pcall(function() x, y = tonumber(v.X), tonumber(v.Y) end)
	if x == nil or y == nil or x ~= x or y ~= y then return nil end
	return x, y, math.sqrt(x * x + y * y)
end

-- The game's speed to lift to (the long sprint's), nil when none is held: movement_ground.lua's floor.
function M.floor(now)
	local f = G.floor
	if f == nil then return nil end
	if now >= f.till then
		G.floor = nil
		return nil
	end
	return f.speed
end

-- The resume's own state cleared while it is off: a move it saw end before is not resumed once it is on again.
local function clear()
	G.special, G.last_game, G.long, G.ended, G.free, G.taken, G.floor = false, nil, nil, nil, nil, nil, nil
end

-- Called every frame while the resume and the faster landing are both off and the mod busy otherwise: only the first
-- call clears. The frame they are turned off always comes here (main.lua decides it is busy from the settings before
-- the change).
function M.stop()
	if G.stopped then return end
	clear()
	G.stopped = true
	Dodge.forget()
end

-- The speed raised to the speed allowed when under it, along the acceleration (ax, ay, acc: read this frame by
-- accel()). Returns the speed before and the one allowed, or nil.
local function raise(cmc, ax, ay, acc)
	local allowed, v = nil, nil
	pcall(function() allowed = tonumber(cmc.MaxWalkSpeed) end)
	pcall(function() v = cmc.Velocity end)
	local _, _, speed = flat(v)
	if allowed == nil or acc == nil or acc <= MOVING or speed == nil or speed >= allowed - MARGIN then return nil end
	local vz = 0
	pcall(function() vz = tonumber(v.Z) or 0 end)
	if not pcall(function() cmc.Velocity = { X = ax / acc * allowed, Y = ay / acc * allowed, Z = vz } end) then
		return nil
	end
	return speed, allowed
end

-- The acceleration on the ground, flat: x, y and its size; nil when unreadable.
local function accel(cmc)
	local a = nil
	pcall(function() a = cmc:GetCurrentAcceleration() end)
	return flat(a)
end

-- After the move: the long sprint held while the game sprints, as long as its own speed stays under it.
local function hold(pawn, mode, now, game, gaits)
	local f = G.floor
	if f ~= nil then
		local sprinting = Tags.look(pawn, now) and Tags.has("sprinting")
		if (mode ~= WALKING and mode ~= FALLING) or sprinting ~= true or (game ~= nil and game >= f.speed - SAME) then
			G.floor = nil
		end
		return
	end
	if G.long == nil or game == nil or gaits == nil or game >= G.long - SAME then return end
	if Tags.look(pawn, now) and Tags.has("sprinting") == true then
		G.floor, G.long, G.holds = { speed = G.long, till = now + HOLD }, nil, G.holds + 1
	end
end

-- cmc, mode: the movement component and its mode. game: the game's own speed this frame and gaits its gait speeds
-- (movement_ground.lua), nil when unknown. rates: the settings' speeds, for the dodge's watch. resume: the sprint resume
-- is on; landing: the faster dodge landing is on. Called while either is on: the dodge's watch serves both.
function M.frame(pawn, cmc, mode, now, game, gaits, rates, resume, landing, say)
	if cmc == nil then return end
	G.stopped = false
	-- Read once a frame on the ground, for the dodge's watch, the end of a special move and the raise.
	local ax, ay, acc = nil, nil, nil
	if mode == WALKING then ax, ay, acc = accel(cmc) end
	local takes = acc ~= nil and acc > MOVING
	local dodged = Dodge.frame(pawn, cmc, mode, takes, now, rates, landing, say)
	if not resume then
		clear()
		return
	end
	if special(mode) then
		if not G.special then
			-- Chained moves: the long sprint held or still waited for after the last one is the one to hold after this.
			local held = G.long or (G.floor and G.floor.speed)
			G.long = held or ((G.last_game ~= nil and gaits ~= nil and G.last_game > gaits.sprint + SAME) and G.last_game
				or nil)
		end
		G.special, G.taken, G.floor = true, nil, nil
		return
	end
	if mode == WALKING or mode == FALLING then G.last_game = game end
	if G.special then G.special, G.ended, G.free, G.look, G.kind = false, now, nil, now, "special move" end
	if G.ended ~= nil and G.taken == nil then
		if now - G.ended > WAIT or (G.free ~= nil and now - G.free > Dodge.TAKEN_WITHIN) then
			G.ended, G.long = nil, nil
		elseif takes then
			G.taken, G.counted, G.told = now, false, false
		elseif mode == WALKING and G.free == nil and now >= G.look then
			-- The exit animation, read every LOOK s on the ground: its end starts the time the stick may come back in.
			G.look = now + Dodge.LOOK
			if Dodge.montage_plays(pawn) == false then G.free = now end
		end
	elseif dodged ~= nil then
		G.ended, G.taken, G.kind, G.counted, G.told = dodged, now, "dodge", false, false
	end
	if G.taken ~= nil then
		hold(pawn, mode, now, game, gaits)
		if mode == WALKING then
			-- Raised again each frame of SNAP as the game lowers the speed: counted and written once a resume.
			local before, after = raise(cmc, ax, ay, acc)
			if before ~= nil then
				if not G.counted then G.counted, G.resumes = true, G.resumes + 1 end
				if not G.told and G.reports < MAX_REPORTS and after - before >= REPORTED then
					G.told, G.reports = true, G.reports + 1
					say("sprint resume: stick taken %.2f s after a %s, speed %.0f raised to %.0f",
						G.taken - G.ended, G.kind, before, after)
				end
			end
		end
		if now - G.taken >= SNAP then G.ended, G.taken, G.long = nil, nil, nil end
	elseif G.floor ~= nil then
		hold(pawn, mode, now, game, gaits)
	end
end

function M.report()
	local text = string.format("%d sprint resumes, %d long sprints held, %d dodge landings sped up", G.resumes, G.holds,
		Dodge.report())
	G.resumes, G.holds = 0, 0
	return text
end

return M
