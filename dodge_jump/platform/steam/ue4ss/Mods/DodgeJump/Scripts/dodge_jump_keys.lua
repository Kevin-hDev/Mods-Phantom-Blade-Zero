-- The buttons, read straight from the controller: the game's jump key cannot be read (its IA_Jump lists no keys), so
-- the mod reads the buttons picked in its settings (dodge_jump_buttons.lua). Each button is read at most once a frame,
-- whichever part of the mod asks.

local M = {}

local fnames = {}                 -- key names as FName, made once per name
local frame = {}                  -- this frame's reads

local function fname(name)
	if fnames[name] == nil then
		local ok, value = pcall(function() return FName(name) end)
		if ok then fnames[name] = value end
	end
	return fnames[name]
end
M.fname = fname

function M.new_frame()
	frame = {}
end

function M.down(controller, name)
	if frame[name] == nil then
		local key = fname(name)
		local ok, down = false, false
		if key ~= nil then
			ok, down = pcall(function() return controller:IsInputKeyDown({ KeyName = key }) end)
		end
		frame[name] = ok and down == true
	end
	return frame[name]
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
