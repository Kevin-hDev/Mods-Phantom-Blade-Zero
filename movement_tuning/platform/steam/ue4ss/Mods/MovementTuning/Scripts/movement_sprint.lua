-- Auto sprint: the left stick pushed all the way starts the sprint, back under the stop point
-- stops it. The mod presses the game's sprint action (SprintInput of the locomotion ability, IA_Sprint, the action of
-- the sprint button) each frame, as a held button (movement_press.lua): the sprint starts in 0.15 s and ends 0.08 s
-- after the last frame (verified in game, 5 November 2026). A frame without the press is the button let go.

local Press = require("movement_press")

local M = {}

local START = 0.99   -- the stick's travel that is all the way: a stick whose reading tops out early still gets there
local FIRST_RETRY = 0.25 -- seconds between two tries in the first SAY_AFTER seconds: a load lacks them a moment
local RETRY = 2      -- seconds between two tries after that (no input subsystem or action)
local SAY_AFTER = 3  -- seconds of such tries before the log says so: a load can lack them a moment

-- active: the mod pressed the sprint at its last frame. action: the sprint action, read again after a press that could
-- not be made. failed: the press itself errs, said once. next_try, missing (since when the press cannot be made), said:
-- the tries while it cannot. starts: sprints started, for the status line.
local G

function M.forget()
	G = { active = false, action = nil, failed = false, next_try = 0, missing = nil, said = false,
		starts = G and G.starts or 0 }
end
M.forget()

local function press(ability, now, say)
	if now < G.next_try then return false end
	local ok, err = false, nil
	for _ = 1, 2 do
		if G.action == nil then pcall(function() G.action = ability.SprintInput end) end
		ok, err = Press.action(G.action)
		if ok or err ~= nil or G.action == nil then break end
		-- Gone, or made again by the game: read once more at once.
		G.action = nil
	end
	if ok then
		G.missing = nil
	elseif err ~= nil then
		G.failed = true
		say("auto sprint cannot press the sprint (%s): it stays off for this character", tostring(err))
	else
		G.missing = G.missing or now
		G.next_try = now + (now - G.missing < SAY_AFTER and FIRST_RETRY or RETRY)
		if not G.said and now - G.missing >= SAY_AFTER then
			G.said = true
			say("auto sprint cannot find the game's sprint to press: it keeps trying")
		end
	end
	return ok
end

function M.active()
	return G.active
end

-- ability: the locomotion ability (nil until found). travel: the left stick's travel, nil when unread. auto: the
-- settings ({ stop }), nil when auto sprint is off. walking: the game walks, or a walk is asked (movement_walk.lua): no
-- sprint, and a sprint going on stops.
function M.frame(ability, travel, auto, walking, now, say)
	if auto == nil or travel == nil or ability == nil or G.failed or walking then
		G.active, G.missing = false, nil
		return
	end
	local wanted = travel >= START or (G.active and travel >= auto.stop)
	-- Counted while the sprint is wanted only: a stick let go is not a sprint missing.
	if not wanted then G.missing = nil end
	if wanted and press(ability, now, say) then
		if not G.active then G.starts = G.starts + 1 end
		G.active = true
	else
		G.active = false
	end
end

function M.report()
	local n = G.starts
	G.starts = 0
	return string.format("%d auto sprints", n)
end

return M
