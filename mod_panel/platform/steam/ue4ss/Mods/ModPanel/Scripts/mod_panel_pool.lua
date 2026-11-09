-- The reserve of rows and list entries the panel shows, never destroyed. A row can show any kind of setting: a band,
-- the chosen band, a label, two arrows, two value texts (the menu's number font and its word font, as no font is handed
-- to the game once built), a button's icon, a bar, an invisible button on the value, a section title's line. So
-- changing mods makes nothing while the reserve is large enough. It grows to the largest mod read (100 rows at most)
-- and to the mods listed (256 at most), never shrinks, and starts empty again in a new frame. Made one object at a time
-- in slices while the panel is hidden (D38), each new piece collapsed until the view shows it.

local L = require("mod_panel_layout")
local Make = require("mod_panel_make")
local Frame = require("mod_panel_frame")
local Slices = require("mod_panel_slices")
local Descriptor = require("mod_panel_descriptor")
local Folders = require("mod_panel_folders")

local M = {}

local MAX_ROWS, MAX_ENTRIES = Descriptor.MAX_ROWS, Folders.MAX_MODS   -- as many as a mod and the list may hold

local want = { rows = 0, entries = 0 }   -- the largest asked for in this session
local P = nil                     -- the reserve of the frame P.frame: { rows, entries, building, slices, broken }

local function hidden(w) w:SetVisibility(L.COLLAPSED) end

local function beside(h, w)
	h:AddChildToHorizontalBox(w):SetVerticalAlignment(L.CENTRE)
end

-- The steps of a row r, each making one object: B, the frame's builder; box, the box that scrolls the rows.
local ROW = {
	function(B, r, box) r.size = B.sized(nil, L.ROW_HEIGHT); hidden(r.size); box:AddChild(r.size) end,
	-- Hit by the pointer, for the row under it (IsHovered).
	function(B, r) r.frame, r.has_band = B.row_frame(); r.frame:SetVisibility(L.VISIBLE); r.size:SetContent(r.frame) end,
	function(B, r) r.overlay = B.new("Overlay"); r.frame:SetContent(r.overlay) end,
	function(B, r) r.band = B.band(); hidden(r.band); Make.fill(r.overlay:AddChildToOverlay(r.band)) end,
	function(B, r)
		r.line = B.sized(nil, L.LINE_HEIGHT)
		hidden(r.line)
		local slot = r.overlay:AddChildToOverlay(r.line)
		slot:SetHorizontalAlignment(L.FILL)
		slot:SetVerticalAlignment(L.END)
	end,
	function(B, r) r.line:SetContent(B.image("line")) end,
	function(B, r) r.h = B.new("HorizontalBox"); Make.fill(r.overlay:AddChildToOverlay(r.h), L.ROW_PADDING) end,
	function(B, r)
		r.label = B.text("font_text", L.TEXT_SIZE, L.WHITE, true)
		local slot = r.h:AddChildToHorizontalBox(r.label)
		slot:SetSize(L.FILL_SIZE)
		slot:SetVerticalAlignment(L.CENTRE)
		slot:SetPadding(L.LABEL_PADDING)
	end,
	function(B, r) r.bar = B.sized(L.SLIDER_WIDTH); hidden(r.bar); beside(r.h, r.bar) end,
	function(B, r) r.slider = B.slider(); r.bar:SetContent(r.slider) end,
	function(B, r) r.left = B.button(); hidden(r.left); beside(r.h, r.left) end,
	function(B, r) r.left_box = B.sized(L.ARROW_SIZE, L.ARROW_SIZE); r.left:SetContent(r.left_box) end,
	function(B, r) r.left_box:SetContent(B.arrow(true)) end,
	function(B, r) r.value = B.button(); beside(r.h, r.value) end,
	function(B, r) r.value_box = B.sized(L.CHOICE_WIDTH); r.value:SetContent(r.value_box) end,
	function(B, r) r.value_overlay = B.new("Overlay"); r.value_box:SetContent(r.value_overlay) end,
	function(B, r)
		r.word = B.text("font_text", L.TEXT_SIZE, L.WHITE)
		Make.centre(r.value_overlay:AddChildToOverlay(r.word))
	end,
	function(B, r)
		r.number = B.text("font_number", L.TEXT_SIZE, L.WHITE)
		hidden(r.number)
		Make.centre(r.value_overlay:AddChildToOverlay(r.number))
	end,
	-- A button row's value as the button's icon (mod_panel_icons.lua), its texture set by the view.
	function(B, r)
		r.icon_box = B.sized(L.ICON_SIZE, L.ICON_SIZE)
		hidden(r.icon_box)
		Make.centre(r.value_overlay:AddChildToOverlay(r.icon_box))
	end,
	function(B, r) r.icon = B.new("Image"); r.icon_box:SetContent(r.icon) end,
	function(B, r) r.right = B.button(); hidden(r.right); beside(r.h, r.right) end,
	function(B, r) r.right_box = B.sized(L.ARROW_SIZE, L.ARROW_SIZE); r.right:SetContent(r.right_box) end,
	function(B, r) r.right_box:SetContent(B.arrow(false)) end,
}

-- The steps of a list entry e: the whole entry is a button, for a click that chooses its mod. A button centres its
-- content and pads it by default: the entry's band and title then shrank to the title's width in 0.1.0, "Off" over the
-- title (a capture of 6 November 2026), so its content fills it.
local ENTRY = {
	function(B, e, box) e.size = B.sized(nil, L.ENTRY_HEIGHT); hidden(e.size); box:AddChild(e.size) end,
	function(B, e) e.button = B.button(); e.size:SetContent(e.button) end,
	function(B, e) e.frame = B.row_frame(); Make.fill(e.button:SetContent(e.frame), L.NO_PADDING) end,
	function(B, e) e.overlay = B.new("Overlay"); e.frame:SetContent(e.overlay) end,
	function(B, e) e.band = B.band(); hidden(e.band); Make.fill(e.overlay:AddChildToOverlay(e.band)) end,
	function(B, e) e.h = B.new("HorizontalBox"); Make.fill(e.overlay:AddChildToOverlay(e.h), L.ENTRY_PADDING) end,
	function(B, e)
		e.title = B.text("font_text", L.TEXT_SIZE, L.WHITE, true)
		local slot = e.h:AddChildToHorizontalBox(e.title)
		slot:SetSize(L.FILL_SIZE)
		slot:SetVerticalAlignment(L.CENTRE)
		slot:SetPadding(L.LABEL_PADDING)
	end,
	function(B, e) e.off = B.text("font_text", L.SMALL_SIZE, L.GREY); hidden(e.off); beside(e.h, e.off) end,
}

-- The reserve of the frame now, a new one with a new frame; nil without a whole frame.
local function current()
	local F = Frame.get()
	if F == nil then return nil end
	if P == nil or P.frame ~= F then
		P = { frame = F, rows = {}, entries = {}, building = nil, slices = { longest = 0 } }
	end
	return P
end

-- The piece being made, or the next one the reserve lacks: the list's entries first.
local function next_piece(R)
	if R.building == nil then
		local F = R.frame
		if #R.entries < want.entries then
			R.building = { steps = ENTRY, list = R.entries, box = F.list, item = {}, step = 1 }
		elseif #R.rows < want.rows then
			R.building = { steps = ROW, list = R.rows, box = F.rows, item = {}, step = 1 }
		end
	end
	return R.building
end

-- The reserve shall hold rows rows and entries entries, within its limits; it never shrinks.
function M.need(rows, entries)
	want.rows = math.max(want.rows, math.min(rows, MAX_ROWS))
	want.entries = math.max(want.entries, math.min(entries, MAX_ENTRIES))
end

-- Makes the reserve's next pieces in a slice of budget seconds, only while the frame is hidden. Returns true once the
-- reserve holds what was asked, false while pieces are left (or the frame shows), or nil and why when the build failed:
-- the piece it was making is left aside, collapsed, and nothing more is made for this frame, as each try would leave
-- one more piece aside. A new frame tries again.
function M.build_step(budget)
	local R = current()
	if R == nil then return nil, "no frame" end
	if R.broken ~= nil then return nil, R.broken end
	if Frame.shows() then return next_piece(R) == nil end
	local ok, done = pcall(Slices.run, function()
		local b = next_piece(R)
		if b == nil then return true end
		b.steps[b.step](R.frame.B, b.item, b.box)
		b.step = b.step + 1
		if b.steps[b.step] == nil then
			b.list[#b.list + 1] = b.item
			R.building = nil
		end
		return next_piece(R) == nil
	end, budget, R.slices)
	if not ok then
		R.building, R.broken = nil, tostring(done)
		return nil, R.broken
	end
	return done
end

-- Row i and entry i of the reserve, whole, or nil.
function M.row(i)
	local R = current()
	return R and R.rows[i]
end

function M.entry(i)
	local R = current()
	return R and R.entries[i]
end

-- How many rows and entries the reserve holds, whole.
function M.counts()
	local R = current()
	if R == nil then return 0, 0 end
	return #R.rows, #R.entries
end

return M
