-- Whether the mouse itself moved (D100). The pointer chooses a row or a head's item, and lights what is under it, only
-- when the mouse moves: what moves under a still pointer (the rows or the list scrolling, the columns sliding) is no
-- gesture. At the trial of 0.4.1, 58 presses of L2 and R2 at the controller alone brought the pointer onto 60 rows,
-- and each took back the move of the button. Its place on the screen is read once a frame while the panel is open
-- (GetMousePositionOnPlatform, Unreal 5.7, WidgetLayoutLibrary.h line 92: the desktop's pixels, as the system has it).
-- Without that function the pointer chooses nothing by passing over, and its clicks still act.

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")

local M = {}

local LIBRARY = Calls.UMG .. "Default__WidgetLayoutLibrary"

-- x, y: the place read at the last frame, nil before the first read of an opening. active: the mouse moved since the
-- last key or button. told: a failure to read the place was said, once a session.
local S = { lib = nil, x = nil, y = nil, active = false, told = false, report = nil }

local function position(lib)
	local v = lib:GetMousePositionOnPlatform()
	return U.num(v.X), U.num(v.Y)
end

-- Asked once a frame while it stays valid (audit of 0.4.3: twice before).
local function library()
	if U.is_valid(S.lib) then return S.lib end
	local ok, lib = pcall(StaticFindObject, LIBRARY)
	S.lib = ok and U.is_valid(lib) and lib or nil
	return S.lib
end

local function fail(why)
	if S.told then return end
	S.told = true
	if S.report then S.report("panel: the mouse's place cannot be read (%s): the pointer acts by its clicks only", why) end
end

-- The mouse's place, or nil.
local function read()
	if not Calls.ok(Calls.MOUSE) then return fail("the engine's function is not the one this version knows") end
	local lib = library()
	if lib == nil then return fail("the engine's widget layout library is not found") end
	local ok, x, y = pcall(position, lib)
	if not ok or not x or not y then return fail(ok and "no place given" or tostring(x)) end
	return x, y
end

-- At each opening; report(fmt, ...) hears of a failure.
function M.start(report)
	S.x, S.y, S.active, S.report = nil, nil, false, report
end

-- The cursor was shown again: the game may have put it elsewhere while it hid it, which is no move of the player's.
function M.rebase()
	S.x, S.y = nil, nil
end

-- At each frame of the open panel; keyed: a key or a button acted in it. Returns whether the mouse moved since the
-- last frame. A move lights what is under the pointer again, a key or a button turns that off.
function M.frame(keyed)
	local x, y = read()
	local moved = x ~= nil and S.x ~= nil and (x ~= S.x or y ~= S.y)
	if x ~= nil then S.x, S.y = x, y end
	if moved then
		S.active = true
	elseif keyed then
		S.active = false
	end
	return moved
end

-- Whether the mouse is in use: it moved since the last key or button.
function M.active() return S.active end

return M
