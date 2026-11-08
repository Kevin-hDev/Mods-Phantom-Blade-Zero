-- The buttons, read straight from the controller: the game's jump keys (vault_jump_keys.lua) and, in a trial build,
-- Circle (vault_watch.lua). Each button is read at most once a frame, whichever part of the mod asks. The
-- controller's IsInputKeyDown is taken once a frame, since UE4SS looks a function up by its name at each call and
-- calls one taken from an object on that object; it is never kept past its frame, tied to its controller. Each key's
-- argument is made once per name, and the frame's reads are cleared rather than made anew. A button that cannot be
-- read counts as up, and the first such read is said.

local M = {}

local MAX_NAMES = 32              -- key names kept: the game's jump keys (8 at most) and Circle; emptied when full
local S = { args = {}, names = 0, frame = {}, controller = nil, fn = nil, say = nil, failed = false }

local function make_fname(name) return FName(name) end
local function method(controller) return controller.IsInputKeyDown end

-- say(fmt, ...): main.lua's event writer.
function M.start(say)
	S.say = say
end

-- The argument IsInputKeyDown takes for a key name, { KeyName = FName }, or nil.
local function argument(name)
	local a = S.args[name]
	if a ~= nil then return a end
	local ok, value = pcall(make_fname, name)
	if not ok then return nil end
	if S.names >= MAX_NAMES then S.args, S.names = {}, 0 end
	a = { KeyName = value }
	S.args[name], S.names = a, S.names + 1
	return a
end
M.argument = argument

function M.new_frame(controller)
	for name in pairs(S.frame) do S.frame[name] = nil end
	local ok, fn = pcall(method, controller)
	S.controller, S.fn = controller, ok and fn or nil
end

function M.down(controller, name)
	local v = S.frame[name]
	if v ~= nil then return v end
	local a, ok, down = argument(name), false, false
	if a ~= nil and S.fn ~= nil and controller == S.controller then ok, down = pcall(S.fn, controller, a) end
	if not ok and not S.failed and S.say ~= nil then
		S.failed = true
		S.say("a button cannot be read (%s): it counts as up; said once", name)
	end
	v = ok and down == true
	S.frame[name] = v
	return v
end

-- A press that starts now, on any of the names: held now, not held at the last read (down: the last reads, updated).
function M.pressed(controller, names, down)
	local pressed = false
	for _, name in ipairs(names) do
		local now = M.down(controller, name)
		if now and not down[name] then pressed = true end
		down[name] = now
	end
	return pressed
end

-- The buttons held now, as the last reads: a button held already is not a new press.
function M.hold(controller, names, down)
	for _, name in ipairs(names) do down[name] = M.down(controller, name) end
end

return M
