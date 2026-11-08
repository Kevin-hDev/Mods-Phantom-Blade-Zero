-- Whether the game is paused, and the jump's and our traversal's clock, which stops while it is. The controller's tick
-- runs during a pause and reads the buttons there, and the game's menus pause it: without this, a pause of more than
-- 4 s during our traversal set the walking mode back in the middle of it, and Cross pressed in a menu during a fall
-- could start our traversal. Read through GameplayStatics's IsGamePaused, only on a press's frame and on the frames of
-- a jump followed or of our traversal.

local R = require("vault_reading")
local Classes = require("vault_classes")

local M = {}

local STATICS = "/Script/Engine.Default__GameplayStatics"
local STATICS_CLASS = "/Script/Engine.GameplayStatics"

-- lib: the library, found once (it always exists); since: when the pause seen last started, in real seconds;
-- total: the seconds of those pauses, taken off the clock; said: an unreadable pause was said.
local S = { lib = nil, since = nil, total = 0, said = false }

local function find() return StaticFindObject(STATICS) end
local function is_paused(lib, controller) return lib:IsGamePaused(controller) end

local function library()
	if R.usable(S.lib, Classes.get(STATICS_CLASS)) then return S.lib end
	local ok, lib = pcall(find)
	S.lib = ok and R.usable(lib, Classes.get(STATICS_CLASS)) and lib or nil
	return S.lib
end

-- true or false; false when the game cannot say, which is said once.
local function paused(say, controller)
	local lib = library()
	local ok, p = false, nil
	if lib ~= nil then ok, p = pcall(is_paused, lib, controller) end
	if ok and type(p) == "boolean" then return p end
	if not S.said then
		S.said = true
		say("whether the game is paused cannot be read: the mod goes on as if it were not; said once")
	end
	return false
end

-- Whether the game is paused now, its time taken off the clock. A pause seen when nothing is followed (a press in a
-- menu), or that outlives what it stopped (a save loaded from the pause menu), is taken off all the same at the next
-- check: nothing timed is under way then, so it only moves the clock on.
function M.check(say, controller, now)
	if paused(say, controller) then
		if S.since == nil then S.since = now end
		return true
	end
	if S.since ~= nil then S.total, S.since = S.total + now - S.since, nil end
	return false
end

-- The jump's and our traversal's clock: the real one less the pauses they spent.
function M.clock(now)
	return now - S.total
end

return M
