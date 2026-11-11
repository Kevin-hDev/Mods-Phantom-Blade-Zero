-- The open panel's parts, each given the others it needs: what the commands change (mod_panel_changes.lua), All mods
-- (mod_panel_all_mods.lua), the controller (mod_panel_controls.lua), the wait for a key (mod_panel_capture.lua), the
-- favourites (mod_panel_favorites.lua), the list, its switches (mod_panel_switches.lua) and its head, the screen, where
-- the player is (mod_panel_nav.lua) and the commands. Out of mod_panel_panel.lua
-- in 0.7.0, which keeps the panel's life.

local Changes = require("mod_panel_changes")
local AllMods = require("mod_panel_all_mods")
local Capture = require("mod_panel_capture")
local Commands = require("mod_panel_commands")
local Controls = require("mod_panel_controls")
local Listing = require("mod_panel_listing")
local Head = require("mod_panel_head")
local Screen = require("mod_panel_screen")
local Nav = require("mod_panel_nav")
local Folds = require("mod_panel_folds")
local Favorites = require("mod_panel_favorites")
local Switches = require("mod_panel_switches")

local M = {}

-- d: as mod_panel_panel.lua's.
function M.new(d)
	local p = { folds = Folds.new(d.state), favorites = Favorites.new(d.state) }
	-- Changes tell All mods of a mod the player turns on, and All mods changes through them: told once both exist.
	p.changes = Changes.new({ catalog = d.catalog, edits = d.edits, own = d.own, folds = p.folds,
		turned_on = function(name) p.all.forget(name) end })
	p.all = AllMods.new({ catalog = d.catalog, changes = p.changes, state = d.state, own = d.own, report = d.report })
	p.controls = Controls.new(d)
	p.capture = Capture.new({ catalog = d.catalog, changes = p.changes, own = d.own, pad_on = p.controls.on,
		report = d.report })
	p.listing = Listing.new(d.catalog, d.state, p.favorites)
	p.switches = Switches.new({ catalog = d.catalog, changes = p.changes, listing = p.listing, own = d.own })
	p.head = Head.new({ catalog = d.catalog, changes = p.changes, state = d.state, own = d.own, all = p.all })
	p.screen = Screen.new({ catalog = d.catalog, own = d.own, changes = p.changes, edits = d.edits,
		capture = p.capture, listing = p.listing, head = p.head, folds = p.folds, favorites = p.favorites,
		switches = p.switches })
	local function classic() return d.settings().classic end
	p.nav = Nav.new({ catalog = d.catalog, listing = p.listing, rows_of = p.screen.rows_of, own = d.own,
		head = p.head, classic = classic })
	p.commands = Commands.new({ nav = p.nav, changes = p.changes, capture = p.capture, controls = p.controls,
		edits = d.edits, catalog = d.catalog, head = p.head, state = d.state, all_rows_of = p.screen.all_rows_of,
		listing = p.listing, favorites = p.favorites, switches = p.switches, classic = classic })
	return p
end

return M
