-- What the open panel shows, worked out at each frame from the catalog, the changes waiting to be written and the
-- panel's state; the view sets in the game only what changed (mod_panel_view.lua, mod_panel_view_head.lua). The head of
-- the list (mod_panel_head.lua); the list the filter shows (mod_panel_listing.lua), the mods' titles in the player's
-- language, each mod's diamond, gold on a favourite (D178), its On/Off switch and its title pale when off (D183), the
-- chosen mod lit, a phrase when none is listed, which says when the search found none or the filter hid those it found;
-- the search field (D186). The chosen mod's rows,
-- each kind as Mods Menu shows it but a button row, whose value is the button's icon (mod_panel_icons.lua), a change
-- waiting shown over the file's value, and a row awaiting a key or a button saying so (mod_panel_capture.lua); under
-- its title, "Settings not saved" while a writing fails. A greyed row in grey, without its arrows (D148); a section's
-- title with "Show" when folded, "Hide" when open, the rows of a folded section left out (D150).
-- The descriptions: the chosen head's item, or the chosen row's and the mod's (mod_panel_about.lua). Restore defaults
-- (or Undo), Close with the panel key and Escape (neither while the search types), and the help of the last device
-- (mod_panel_hints.lua). The columns where the descriptions shown or hidden want them, with Hide and Show (D90).

local L = require("mod_panel_layout")
local Text = require("mod_panel_text")
local Keys = require("mod_panel_keys")
local KeyNames = require("mod_panel_key_names")
local Values = require("mod_panel_values")
local Words = require("mod_panel_words")
local View = require("mod_panel_view")
local ViewHead = require("mod_panel_view_head")
local FrameHead = require("mod_panel_frame_head")
local Hints = require("mod_panel_hints")
local Icons = require("mod_panel_icons")
local PadNames = require("mod_panel_pad_names")
local ComboRow = require("mod_panel_combo_row")
local Page = require("mod_panel_page")
local About = require("mod_panel_about")

local M = {}

-- d: { catalog (the mods read), own (Mod Panel's folder name), changes (mod_panel_changes.lua) and edits
-- (mod_panel_edits.lua): what the commands changed; capture (mod_panel_capture.lua): the wait for a key; listing
-- (mod_panel_listing.lua), head (mod_panel_head.lua), folds (mod_panel_folds.lua), favorites
-- (mod_panel_favorites.lua), switches (mod_panel_switches.lua), search (mod_panel_search.lua) }.
function M.new(d)
	local catalog, own, changes, edits, capture = d.catalog, d.own, d.changes, d.edits, d.capture
	local S = { lang = "en", close = "", key_shown = nil, back_shown = false, typing_shown = false }
	local looks, heads = {}, {}       -- by row, by head's item: its look, a table used again at each frame
	local page = Page.new(own, d.folds)
	local about = About.new({ own = own, changes = changes, capture = capture })
	S.all_rows_of, S.rows_of = page.all_rows_of, page.rows_of

	local function say(name) return Words.say(name, S.lang) end
	local function pick(t) return Text.pick(t, S.lang) end

	-- Close and the keys that close: the panel key and Escape, but Escape while it comes back to the list (back), and
	-- neither while the search types (D186), where Escape erases and a panel key that is a letter types it (audit of
	-- 1.0.4).
	local function close_with(key_label, back, typing)
		S.key_shown, S.back_shown, S.typing_shown = key_label, back, typing
		local escape = not back and say("escape") or nil
		local keys = not typing and (key_label and escape and key_label .. " / " .. escape or key_label or escape) or nil
		S.close = keys and say("close") .. L.FOOTER_GAP .. keys or say("close")
	end

	-- At each opening: the texts in lang ("en", "zh-Hans"...), and key_label, the panel key's name on Close (nil for
	-- none).
	function S.start(lang, key_label)
		S.lang = lang
		close_with(key_label, false, false)
	end

	-- The panel key's name now, ten times a second while the panel is open: Close made again when it changed (audit of
	-- 0.4.3: the key changed in the panel worked, and Close said the old one until the next opening).
	function S.key_now(key_label)
		if key_label ~= S.key_shown then close_with(key_label, S.back_shown, S.typing_shown) end
	end

	-- The look of a row of value v (k: a table used again); word: what an action row says now (nil for "Run"), or
	-- what a row awaiting a key or a button says; first: the button a wait of the combination took first; v2: the
	-- combination's second button, v its first; folded: a title's section is folded; greyed: the row waits for
	-- another setting.
	local function look(k, row, v, selected, word, first, v2, folded, greyed)
		k.kind, k.selected, k.label = row.type, selected, pick(row.label) or row.key or ""
		k.value, k.number, k.bar, k.fraction, k.arrows, k.grey, k.button = "", false, false, 0, false, false, nil
		local kind = row.type
		if kind == "heading" then
			k.value = say(folded and "show" or "hide")
			return k
		end
		if kind == "combo" then
			-- The buttons by their names on the controller in use, not their icons (D135).
			k.arrows = true
			if first ~= nil then
				k.value = Icons.label(first, S.lang) .. " + ..."
			elseif word ~= nil then
				k.value = say(word)
			else
				local brand = Icons.brand()
				if k.a ~= v or k.b ~= v2 or k.lang ~= S.lang or k.brand ~= brand then
					k.a, k.b, k.lang, k.brand = v, v2, S.lang, brand
					k.pair = v and Icons.label(v, S.lang) .. " + " .. Icons.label(v2, S.lang) or say("none")
				end
				k.value = k.pair
			end
			return k
		end
		if kind == "choice" and word ~= nil then
			k.value, k.arrows = say(word), true
		elseif kind == "action" then
			k.value = say(word or "run")
		elseif kind == "readonly" then
			k.value, k.grey = v == nil and "" or Values.js_string(v), true
		elseif kind == "toggle" then
			k.value, k.arrows = say(v and "on" or "off"), true
		elseif v ~= nil then
			if kind == "number" then
				k.value, k.number = Values.format_number(v, row), true
			elseif row.button_row and PadNames.known(v) then
				-- The button as the controller in use shows it, its icon over its name (mod_panel_view.lua).
				k.value, k.button = Icons.label(v, S.lang), v
			else
				local i = Values.option_index(row.options, v)
				k.value = i and pick(row.options[i].label) or row.key_row and KeyNames.label(v, S.lang)
					or Values.js_string(v)
			end
			if row.slider then k.bar, k.fraction = true, Values.fraction(row, v) else k.arrows = true end
		end
		if greyed then k.grey, k.arrows = true, false end
		return k
	end

	-- The head of the list: each of the frame's items, the chosen one lit (head: its place among the items shown).
	local function paint_head(head)
		ViewHead.words(say("on"), say("off"))
		local chosen = head and d.head.name(head)
		for i, name in ipairs(FrameHead.ITEMS) do
			heads[i] = d.head.look(heads[i] or {}, name, S.lang)
			ViewHead.item(i, heads[i], name == chosen)
		end
	end

	-- state: { mod, the chosen mod's name; row, the chosen row's place among rows_of (nil: none); head, the chosen
	-- item's place in the head (nil: a row is chosen); hover, the place of the list's entry under the pointer (nil:
	-- none); on_restore, the pointer on Restore defaults; lit, "hide" or "show" under the pointer; opacity, the
	-- backdrop's %; color, its Background color (D177); icons, ButtonIcons in use; descriptions, whether they show;
	-- now, the clock; back, whether Escape and Circle come back to the list }.
	function S.paint(state)
		Icons.use(state.icons)
		local typing = Keys.typing()
		if (state.back == true) ~= S.back_shown or typing ~= S.typing_shown then
			close_with(S.key_shown, state.back == true, typing)
		end
		local list = d.listing.list(state.mod)
		local chosen = state.mod and catalog.get(state.mod) or nil
		local rows = chosen and S.rows_of(chosen) or {}
		local on_row = state.head == nil and state.row or nil
		local row = on_row and rows[on_row]
		local v = row and row.key and changes.value(chosen, row)
		local count = string.format(say(#list == 1 and "mod_count_one" or "mod_count"), #list)
		local sub = chosen and edits.not_saved(chosen.name) and say("not_saved") or ""
		local about = state.head and d.head.describe(state.head, S.lang)
			or chosen and about.of(chosen, row, v, state.now, S.lang) or ""
		View.texts(say("title"), count, chosen and pick(chosen.title) or "", sub, about, S.close)
		paint_head(state.head)
		local search = d.search
		ViewHead.search(search.text(), typing, say("search"))
		local empty = not search.active() and "empty" or d.listing.hidden() > 0 and "search_hidden" or "search_none"
		ViewHead.empty(say(empty), #list == 0)
		local on_word, off_word = say("on"), say("off")
		for i, entry in ipairs(list) do
			local sw, locked = d.switches.look(entry)
			View.entry(i, pick(entry.title) or entry.name, entry == chosen, i == state.hover, d.favorites.is(entry.name),
				sw, locked, on_word, off_word)
		end
		for i, r in ipairs(rows) do
			looks[i] = looks[i] or {}
			local word = r.type == "action" and changes.word(chosen, r, state.now) or capture.shows(chosen, r)
			local value, second = nil, nil
			if r.type == "combo" then
				value, second = ComboRow.pair(changes.value, chosen, r)
			elseif r.key then
				value = changes.value(chosen, r)
			end
			local folded = r.type == "heading" and d.folds.is_folded(chosen, r)
			View.row(i, look(looks[i], r, value, i == on_row, word, capture.first(chosen, r), second, folded,
				changes.locked(chosen, r) ~= nil))
		end
		View.hide_from(#rows + 1, #list + 1)
		local label = chosen and changes.label(chosen, S.all_rows_of(chosen))
		View.restore(label and say(label), state.on_restore)
		local keys, pad, words = Hints.lines(S.lang, label, state.back, typing)
		View.hints(keys, pad, words, Hints.device())
		View.backdrop(state.opacity, state.color)
		ViewHead.columns(state.descriptions, say("hide"), say("show"), state.lit)
	end

	return S
end

return M
