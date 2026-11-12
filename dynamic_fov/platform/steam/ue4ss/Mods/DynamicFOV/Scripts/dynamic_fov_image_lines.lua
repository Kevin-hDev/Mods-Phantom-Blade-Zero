-- The lines of the colours and the clean image (dynamic_fov_image.lua). Not while the panel is open: each click on
-- Colours or Clean image would say it. The last line is held and said once the panel is closed, so the log tells what
-- the camera ended up with (silent before 1.0.3's trial of 5 November 2026). What went wrong is said even while the
-- panel is open, under its own bound: routine lines never silence it.

local Image = require("dynamic_fov_image")

local M = {}

-- T: the mod's lines and counts (dynamic_fov_status.lua); is_open(): whether the panel is open; controller():
-- the player controller. Returns look(), which looks at the image settings and says what changed, and born(),
-- which gives the image to the cameras the game just made.
function M.new(T, is_open, controller)
	local held = nil

	local function report(fmt, ...)
		local line = string.format(fmt, ...)
		if is_open() then held = line return end
		held = nil
		T.bounded("image", "%s", line)
	end

	local function problem(fmt, ...)
		T.bounded("image problem", fmt, ...)
	end

	local function count(writes, failed)
		T.image_writes, T.image_failed = T.image_writes + writes, T.image_failed + failed
		if held ~= nil and not is_open() then
			local line = held
			held = nil
			T.bounded("image", "%s", line)
		end
	end

	return function()
		count(Image.look(controller(), report, problem))
	end, function()
		local writes, failed = Image.born(report, problem)
		T.image_early = T.image_early + writes
		count(writes, failed)
	end
end

return M
