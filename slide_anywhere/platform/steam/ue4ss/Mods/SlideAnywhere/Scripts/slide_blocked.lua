-- How rocks, walls and fences slow a slide, from the distance the character really moved (used by slide_run.lua).
-- The game's velocity cannot tell: in the trial of 0.5.0 it stayed at the speed pushed while the character stood
-- still against a wooden fence for 5 s (slide #17, its height unchanged to the centimetre), so only the position is
-- trusted.

local M = {}

-- Every STEP, the real flat speed against the speed pushed over the step.
-- Under SLOWED, the obstacle took that speed and the slide goes on from the real speed. Pushed on at its old speed,
-- it burst forward once past the snag; Kevin, 5 November 2026: "j'ai l'impression que le mod me fait repartir super
-- vite, comme s'il cherchait à rattraper du retard" (trial of 0.5.1, slide #62: 1585 moved for 2114 pushed, back
-- at 2040 0.1 s later). Over SLOWED, the gap is the measure's own noise or a wall grazed (in that trial, most
-- readings at 0.9 to 1.1).
-- Under SHARE, the obstacle took more than half the speed: the slide ends there, against a fence or a rock (Kevin,
-- of 0.5.0: "les rochers je passe au-dessus doucement sans être stoppé"). A STEP spans a few frames, so a character
-- thrown back and forth from one frame to the next still counts as stopped.
M.SLOWED = 0.8
M.SHARE = 0.5
M.STEP = 0.05    -- s

local function restart(w, pos)
	w.block = { pos = pos, t = 0, pushed = 0 }
end

-- w: the slide, w.written the speed pushed at the last frame and w.written_dt that frame's time, the time the game
-- moved the character at that speed (counted with the next frame's time, one long frame made a slide in open ground
-- look blocked: audit of 0.5.2, reproduced in the fake game); pos: the character's position this frame. Once per
-- STEP, sets w.moved, the real flat speed over it. Returns blocked, true when the slide must end; slowed, the real
-- speed when the slide must go on from it, else nil.
function M.check(w, pos)
	if pos == nil or w.written == nil then
		w.block = nil
		return false
	end
	local b = w.block
	if b == nil then
		restart(w, pos)
		return false
	end
	b.t, b.pushed = b.t + w.written_dt, b.pushed + w.written * w.written_dt
	if b.t < M.STEP then return false end
	local dx, dy = pos.x - b.pos.x, pos.y - b.pos.y
	local moved = math.sqrt(dx * dx + dy * dy)
	w.moved = moved / b.t
	restart(w, pos)
	if moved < M.SHARE * b.pushed then return true end
	return false, moved < M.SLOWED * b.pushed and w.moved or nil
end

return M
