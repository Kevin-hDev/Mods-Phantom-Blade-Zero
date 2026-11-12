-- A key held in the search field writes again, as in any text field (D187). UE4SS calls a bind once per press
-- (mod_panel_keys.lua): once the key last typed has been down for DELAY, it is asked of the game held at each frame
-- (IsInputKeyDown, mod_panel_controls.lua), and writes again every RATE while it is, Windows' pace by default
-- (SystemParametersInfo: keyboard delay 1, about 500 ms; keyboard speed 31, about 30 a second). A new key typed takes
-- over, as in Windows; Up, Down, the end of the typing or the key let go stop it. Just after the panel let go of the
-- keys held (mod_panel_flush.lua), a key held reads let go until Windows repeats it: it then neither writes nor stops.

local Names = require("mod_panel_key_names")
local Flush = require("mod_panel_flush")

local M = {}

local DELAY = 0.5                 -- seconds a key is down before it writes again
local RATE = 1 / 30               -- seconds between two writings
local MAX_FRAME = 4               -- writings in one frame at most: a frame that took long writes no burst
local NONE = {}

-- token: the key last typed, as mod_panel_search.lua takes it ("a", "1", " ", "\b"), nil for none; at: when it may
-- write again.
local S = { token = nil, at = 0 }

-- The repeat stops: the typing ended, or Up or Down was pressed.
function M.stop() S.token = nil end

-- Whether a key that writes token is held, asked with down(name).
local function held(token, down)
	for _, name in ipairs(Names.HELD[token] or NONE) do
		if down(name) then return true end
	end
	return false
end

-- At each frame the field types: typed, what the keys wrote in this frame (nil for nothing); now, the clock;
-- down(name), whether the key called name (the engine's) is held. Returns the key that writes again and how many
-- times, or nil.
function M.frame(typed, now, down)
	if typed ~= nil then
		S.token, S.at = typed[#typed], now + DELAY
		return nil
	end
	if S.token == nil or now < S.at then return nil end
	if not held(S.token, down) then
		if Flush.quiet(now) then S.at = now else S.token = nil end
		return nil
	end
	local n = math.min(MAX_FRAME, math.floor((now - S.at) / RATE) + 1)
	S.at = S.at + n * RATE
	if S.at <= now then S.at = now + RATE end
	return S.token, n
end

return M
