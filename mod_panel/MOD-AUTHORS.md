# Mod Panel: guide for mod authors

Mod Panel is an in-game settings panel for the UE4SS mods of Phantom Blade Zero. It reads the same two files as Mods Menu: **if your mod already shows its settings in Mods Menu, it shows them in Mod Panel too, with nothing to change.** Mod Panel does not need Mods Menu, and players may have either one, or both. JavaScript mods made for Mods Menu need it to run, and show in Mod Panel while it runs them ([section 2](#javascript-mods)).

This guide describes Mod Panel 1.0.0: which mods it lists, the whole format of the files it reads, what it writes, and how your mod takes a change at once.

[简体中文版](MOD-AUTHORS.zh-CN.md)

## Contents

1. [Quick start](#1-quick-start)
2. [Which mods are listed](#2-which-mods-are-listed)
3. [The settings file](#3-the-settings-file)
4. [The description file](#4-the-description-file)
5. [How Mod Panel writes your settings](#5-how-mod-panel-writes-your-settings)
6. [Taking a change at once: the signal file](#6-taking-a-change-at-once-the-signal-file)
7. [If your mod has its own panel, or reads buttons itself](#7-if-your-mod-has-its-own-panel-or-reads-buttons-itself)
8. [Checking your files](#8-checking-your-files)
9. [Licence](#9-licence)

## 1. Quick start

Your mod's folder, in `platform\steam\ue4ss\Mods\`:

```
MyMod\
    enabled.txt              UE4SS starts the mod
    Scripts\main.lua         your code
    MyMod.config.json        the settings, written by your mod at its first start
    MyMod.modsmenu.json      how each setting shows (optional, but strongly advised)
```

`MyMod.config.json`, a single JSON object:

```json
{
  "Enabled": true,
  "Strength": 1.5
}
```

`MyMod.modsmenu.json`:

```json
{
  "title": { "en": "My Mod", "zh-Hans": "我的模组" },
  "description": "What the mod does, in one or two sentences.",
  "version": "1.0.0",
  "settings": [
    { "key": "Enabled", "type": "toggle", "label": "Enabled", "default": true },
    { "key": "Strength", "type": "number", "label": "Strength", "default": 1.5, "min": 0, "max": 3, "step": 0.1,
      "help": "How strong the effect is. 1 is the game's." }
  ]
}
```

That is enough for the panel to list your mod and change its settings. To take a change while the game runs, without a restart, read the signal file once a second ([section 6](#6-taking-a-change-at-once-the-signal-file)).

## 2. Which mods are listed

A mod is listed when all of these hold:

- UE4SS starts it: its folder holds an `enabled.txt`, or `Mods\mods.txt` has a line `MyMod : 1`.
- Its folder name uses only letters, digits, `_`, `-`, `.`, spaces and parentheses, 64 characters at most, and is not only dots.
- Its folder holds `<FolderName>.config.json`, with one JSON object in it, 256 KiB at most.
- At least one of its rows can be used ([section 4](#4-the-description-file)).

The bridge folder `PBZModsMenuBridge` and the `shared` folder are never listed. Mod Panel lists 256 mods at most.

**Order:** Mod Panel first, then the mods by their English title, whatever the case of the letters, then by folder name. The order is the same in every language.

**On and off:** a `toggle` row whose key is `Enabled` is your mod's switch. By default, the list shows only the mods that are on (the box `Mod enabled` is checked, `Mod disabled` is not); a mod without an `Enabled` row counts as on. Give your mod an `Enabled` row, first in the list, so that players can turn it off and shorten the list. `All mods`, at the top of the list, turns off in one press every mod that has this row, and later turns back on only those; a mod without it keeps running, and a mod whose `Enabled` row is greyed is left alone. The change reaches your mod like any other ([section 6](#6-taking-a-change-at-once-the-signal-file)).

**When files are read:** the description file at the start of the game, then again at each opening of the panel when its text has changed; the settings file at each opening. A change your mod or the player makes to these files shows the next time the panel opens.

### JavaScript mods

A JavaScript mod made for Mods Menu, which gives Mods Menu its settings with `PBZModsMenu.push`, is listed too, while Mods Menu runs it. A small JavaScript file shipped with Mod Panel, `AAModPanelLink`, passes on to Mod Panel what each mod gives Mods Menu: there is nothing to add to your mod. Mod Panel then reads and writes your Key=Value settings file as Mods Menu does, and makes it, with its folder, at the first change if it is not there yet. In Mod Panel:

- `action` rows are left out: they run a function inside the game's scripts, out of Mod Panel's reach;
- a `choice` row with an option whose value holds `;` or `#` is left out: a Key=Value file reads these as the start of a comment;
- no signal file is written ([section 6](#6-taking-a-change-at-once-the-signal-file)): your mod reads its file again by itself.

Mod Panel lists 64 JavaScript mods at most. Their list is read again at each opening of the panel.

## 3. The settings file

`<FolderName>.config.json`, beside your `Scripts` folder:

- **Your mod writes it**, with its default values, at its first start. Mod Panel never creates a settings file, and never writes one that is read-only.
- **One JSON object.** Mod Panel changes only the values the player changes, and keeps every other key as it is, unknown keys included ([section 5](#5-how-mod-panel-writes-your-settings)).
- **Read it tolerantly:** ignore a key you do not know, give a missing key its default, and treat a file you cannot read as defaults, with a line in your log. A player may edit the file by hand.
- **If your mod writes it again later** (to add a key after an update, for example), write a temporary file, then rename it over the old one, so the file is never seen half written.

A key that no row of the description file names still gets a row, from its value:

| Value in the file | Row |
|---|---|
| `true` or `false` | `toggle` |
| a number | `number`, step 1 for a whole number and 0.1 otherwise, no bounds and no bar |
| a string | `readonly`: the text is shown, greyed, and cannot be changed |
| an object, an array or `null` | no row |

Such a row has no default: `Restore defaults` leaves it as it is. Its key must follow the rule of row keys ([section 4](#common-fields)). Describe every setting in the description file instead: the player then gets a label, an explanation, bounds and a default.

## 4. The description file

`<FolderName>.modsmenu.json`, beside the settings file, 256 KiB at most. Without it, or when it is not valid JSON, the rows come from the settings file alone, and the reason goes to the log.

### The mod

| Field | What it is |
|---|---|
| `title` | A [text](#texts), 80 characters at most. Without it, the folder name |
| `description` | A text, 300 characters at most, shown at the bottom of the descriptions column with the version |
| `version` | A string, 20 characters at most |
| `settings` | An array of rows, in the order they show. A mod shows 100 rows at most: yours first, then the rows made from the settings file ([section 3](#3-the-settings-file)) |
| `greyedUnless` | A [condition](#greyed-rows) that greys every row of the mod while it is not met |

### Texts

A text is either a string, in English, or an object of languages:

```json
"label": { "en": "Strength", "fr": "Force", "ja": "強さ", "zh-Hans": "强度", "zh-Hant": "強度" }
```

- `en` is required: a text without English counts as absent.
- The other languages of the game are optional: `de`, `es-419` (Latin American Spanish), `es-ES`, `fr`, `it`, `ja`, `ko`, `pt-BR`, `pt-PT`, `ru`, `th`, `vi`, `zh-Hans` (Simplified Chinese) and `zh-Hant` (Traditional Chinese), the codes Mods Menu reads too. Common other spellings are read as well (`zh-CN`, `zh-TW`, `es`, `pt`, `ja-JP`...); the exact code wins over another spelling. Any other key is ignored.
- The panel shows its own language: the game's, or the one the player chose in Mod Panel's `Language` row. A text missing in that language takes its neighbour (Simplified and Traditional Chinese, the two Spanish, the two Portuguese), then English.
- Spaces at both ends are taken away, and a text longer than its limit is cut.

### Common fields

| Field | What it is |
|---|---|
| `type` | Required: `toggle`, `choice`, `number`, `key`, `action`, `heading` or `readonly` |
| `key` | Required, except on a `heading`: the setting's key in the settings file. Letters, digits and `_` only, 64 characters at most |
| `label` | A text, 80 characters at most. Without it, the key |
| `help` | A text, 400 characters at most, shown in the descriptions column while the row is selected |
| `restart` | `true`: "Applies after a restart." shows under the help. For a setting your mod reads only when the game starts |
| `default` | Required on `toggle`, `choice`, `key` and `number`: the value `Restore defaults` puts back |
| `missing` | The value shown when the key is absent from the settings file, or its value there cannot be used. Without it, the default |
| `greyedUnless` | A [condition](#greyed-rows): the row is greyed while it is not met |
| `neverGreyed` | `true`: the mod's `greyedUnless` never greys this row |

### `toggle`

On or Off. Written as `true` or `false`. Read from `true` or `false`, and also from `"on"`, `"off"`, `"yes"`, `"no"`, `"true"`, `"false"`, `1` and `0`.

```json
{ "key": "CleanImage", "type": "toggle", "label": "Clean image", "default": false,
  "help": "On: no vignette, film grain or bloom. Off: the game's image." }
```

### `choice`

A list of options, stepped with left and right.

- `options`: 1 to 64 options. Each is a value (a string, a number, `true` or `false`), or an object `{ "value": ..., "label": text }`. The value as written is 64 characters at most, on one line; a label is 40 characters at most. Without a label, the value is shown.
- `default` must be one of the values.
- Written as the option's value, with its JSON type: `"Far"`, `2`, `true`.
- `"slider": true` shows the row as a bar, when it has two options or more and every value is a number, except one word at most, first or last (`"Off", 1, 2, 3`).

```json
{ "key": "Preset", "type": "choice", "label": "Preset", "default": "Default",
  "options": [
    { "value": "Close", "label": "Close" },
    { "value": "Default", "label": "Default" },
    { "value": "Far", "label": "Far" }
  ] }
```

**Controller buttons.** When every value of a `choice` is a button name from the table below or `"None"`, with one button at least, the panel shows each button as its PlayStation or Xbox icon, and, while a controller is in use, Cross on the row waits for the player to press one of the buttons of the list. Nothing to add: use the engine's names as values. The buttons the game has no icon for (the touchpad, Options, View, Menu and the stick directions) show as their name.

| Value | PlayStation | Xbox |
|---|---|---|
| `Gamepad_FaceButton_Bottom` | Cross | A |
| `Gamepad_FaceButton_Right` | Circle | B |
| `Gamepad_FaceButton_Left` | Square | X |
| `Gamepad_FaceButton_Top` | Triangle | Y |
| `Gamepad_LeftShoulder`, `Gamepad_RightShoulder` | L1, R1 | LB, RB |
| `Gamepad_LeftTrigger`, `Gamepad_RightTrigger` | L2, R2 | LT, RT |
| `Gamepad_LeftThumbstick`, `Gamepad_RightThumbstick` | L3, R3 | LS, RS |
| `Gamepad_DPad_Up`, `_Down`, `_Left`, `_Right` | D-pad | D-pad |
| `Gamepad_LeftStick_Up`, `_Down`, `_Left`, `_Right` | Left stick | Left stick |
| `Gamepad_RightStick_Up`, `_Down`, `_Left`, `_Right` | Right stick | Right stick |
| `Gamepad_Special_Left` | Touchpad | View |
| `Gamepad_Special_Right` | Options | Menu |
| `PBZ_Gamepad_Create` | Create (the game's own button name) | none (the Xbox controller has no such button) |

The D-pad and stick directions are written in full: `Gamepad_DPad_Down`, `Gamepad_LeftStick_Up`, and so on. The touchpad and Options open the game's map and menu: think twice before offering them.

### `number`

A number, stepped with left and right; a held arrow speeds up.

- `step`: required, above 0. The value is written with the decimals of the step (`0.1` gives one decimal).
- Read from a number, and also from a text that holds one (`"2"`, `"2,5"`).
- `min`, `max`: optional; `min` not above `max`. Stepping stops at both ends.
- `default` must lie between `min` and `max`.
- With `min` and `max`, the row shows a bar; `"slider": false` shows the value between two arrows instead.

```json
{ "key": "Distance", "type": "number", "label": "Distance", "default": 0, "min": -50, "max": 100, "step": 5,
  "help": "In % of each view's own distance. 0 is the game's." }
```

### `key`

A keyboard key. Its options are fixed; do not write `options`. Written as the engine's name of the key, or `"None"`. `default` must be one of these names:

`None`, `F1` to `F9`, `F12`, `PageUp`, `PageDown`, `Home`, `End`, `Insert`, `Delete`, `NumPadZero`, `NumPadOne`, `NumPadTwo`, `NumPadFour` to `NumPadNine`, `Multiply`, `Add`, `Subtract`, `Decimal`, `Divide`, `G`, `H`, `J`, `L`, `N`, `U`, `Y`, `Zero`, `Nine`.

These are the keys the game leaves free. Cross on the row waits for a key press; Escape cancels, and the wait ends by itself after 5 seconds. The panel does not offer F9, which opens Mods Menu by default, nor a key that another key row of a listed mod already uses, Mod Panel's own panel key included. `F9` is still accepted as a `default`, and `Restore defaults` leaves a key row as it is when another key row already uses its default.

```json
{ "key": "PanelKey", "type": "key", "label": "Panel key", "default": "F8" }
```

### `action`

A button that tells your mod to do something now, such as resetting a camera. The first press arms it ("Press again", 3 seconds), the second sends it, and the row shows "Sent". Nothing is written in the settings file: the action goes through the signal file ([section 6](#actions)).

```json
{ "key": "ResetCamera", "type": "action", "label": "Reset the camera",
  "help": "Puts the camera back behind the character." }
```

### `heading`

A title over the rows that follow it, down to the next title. `label` is required; no `key`.

```json
{ "type": "heading", "label": { "en": "Camera position", "zh-Hans": "镜头位置" } }
```

Every title folds the rows under it: the player selects it and presses Cross, Enter, Left or Right, or clicks its "Show" or "Hide". `collapsed: true` makes the section start folded; without it, it starts open. Mod Panel keeps each section as the player left it until the game closes, and never writes it to a file. `Restore defaults` also puts back the rows of a folded section.

```json
{ "type": "heading", "label": { "en": "Advanced", "zh-Hans": "高级" }, "collapsed": true }
```

### `readonly`

A value shown greyed, which the player cannot change: the value of its key in the settings file. `key` is optional.

```json
{ "key": "Build", "type": "readonly", "label": "Build", "help": "Written by the mod at its start." }
```

### Greyed rows

`greyedUnless` holds a condition: an object whose keys are settings of the mod, each with the value it must have, or a list of values. The row is greyed while one of these settings has none of its values.

```json
{
  "title": "My Mod",
  "greyedUnless": { "Enabled": true },
  "settings": [
    { "key": "Enabled", "type": "toggle", "label": "Enabled", "default": true },
    { "key": "Preset", "type": "choice", "label": "Preset", "default": "Default",
      "options": [ { "value": "Off", "label": "Off" }, { "value": "Default", "label": "Default" },
                   { "value": "Custom", "label": "Custom" } ] },
    { "key": "Strength", "type": "number", "label": "Strength", "default": 50, "min": 0, "max": 100, "step": 5,
      "greyedUnless": { "Preset": "Custom" } },
    { "key": "Speed", "type": "number", "label": "Speed", "default": 1, "min": 1, "max": 3, "step": 1,
      "greyedUnless": { "Preset": ["Default", "Custom"] } },
    { "key": "PanelKey", "type": "key", "label": "Panel key", "default": "F8", "neverGreyed": true }
  ]
}
```

- **On a row**, the condition greys that row only. Above, Strength is greyed unless Preset is Custom, and Speed while Preset is Off.
- **On the mod**, it greys every row but its titles, its `readonly` rows, the settings it names and the rows marked `neverGreyed: true`. Above, everything is greyed while Enabled is off, except Enabled itself and the panel key.
- A greyed row can still be selected. Its description then shows, under its label, "Set Preset to Custom to change this row.", made from your labels and options, in the player's language, before your help; when the condition lists several values, the first is named, and when both conditions are unmet, the mod's is said first. Nothing changes a greyed row (arrows, Cross, Enter, clicks, the bar, waiting for a key), but `Restore defaults` and `Undo`.
- The condition is read with the values the panel shows, a change not yet saved included: Strength opens as soon as the player sets Preset to Custom.
- A setting named in a condition is left out of it, with a line in the log, when it is not a `toggle`, `choice` or `number` row of the mod (a `key`, `action`, `heading` or `readonly` row cannot be named), when it is the row's own key, when it is given a value it cannot take, or an empty list of values, or more than 64. A condition that names more than 100 settings is ignored whole. A `greyedUnless` on a `heading` or a `readonly` row has no effect. Mods Menu ignores `greyedUnless`, `neverGreyed` and `collapsed`: adding them changes nothing there.

### Rows left out

A row that breaks a rule above is left out, with a line in the log ([section 8](#8-checking-your-files)); the other rows still show. The usual reasons: an unknown `type`, a missing or invalid `key`, a missing `default`, a `default` that is not one of the options or lies outside `min` and `max`, a `step` of 0 or below, `min` above `max`, an empty `options` list or more than 64. A row counts as usable when it has a `key`: titles, and `readonly` rows without one, do not. A mod with no usable row is not listed.

## 5. How Mod Panel writes your settings

- **When:** half a second after the player's last change, and also before the panel goes to another mod, before an action is sent, and when it closes.
- **What:** Mod Panel reads the file again just before, then changes only the values the player changed, in place in the text. Every other key, the order of the keys, the spacing and the unknown keys stay as they were; a key absent from the file is added before its last brace.
- **How:** a temporary file `<file>.modpanel-tmp` is written, the old file is set aside as `<file>.modpanel-bak` for the moment of the swap, then the new file takes its place. If the game stops in the middle, Mod Panel puts the set-aside file back at the next start when the settings file is missing, and renames it `<file>.modpanel-kept` otherwise; it never deletes it. Your mod can ignore these three names.
- **If the file is busy** (another program holds it): Mod Panel tries again each second, five tries in all, and the panel says "Settings not saved" meanwhile; the last failure goes to the log with its reason.
- **Values:** a `toggle` as `true` or `false`, a `number` as a JSON number, a `choice` as its option's value, a `key` as a string. A text is written in ASCII: a character beyond it becomes `\uXXXX`, which every JSON reader decodes.
- **Then** it tells your mod through the signal file, never before the settings file is written.

## 6. Taking a change at once: the signal file

After each settings file it writes, and for each action, Mod Panel writes a small signal file for your mod. Mods Menu writes the same file, in the same form: **one reader serves both menus.** This section is for UE4SS mods: JavaScript mods get no signal file ([section 2](#javascript-mods)).

**Where:** `platform\steam\ue4ss\Mods\PBZModsMenuBridge\events-<FolderName>.txt`. In the file name, letters, digits and `_` stay as they are; every other byte becomes `%` followed by two lowercase hex digits (`My Mod` gives `events-My%20Mod.txt`). Mod Panel creates the folder when it is missing, if the game lets it; otherwise it says so in the log, and your mod takes the change at its next start.

**What it holds**, with Windows line ends:

```
; Mod Panel events for MyMod: numbers only grow, one per event.
Changed=1793000123456
Action=1793000123457 ResetCamera
End=1
```

- `Changed=<n>`: the number grows each time your settings file has been written. A number higher than the last one you saw means: read your settings file again. It may be empty when the file only carries actions.
- `Action=<n> <key>`: an action row's key, one line per action your mod has not done yet; the 16 latest are kept.
- `End=1`: the file is whole. Without this line, it is still being written: try again the next second.
- The numbers only grow: they start from the time in milliseconds since 1970, and each new event takes a higher one. Compare them as numbers.

**What your mod does, once a second:**

1. Read the file. If it is missing or has no `End=1` line, do nothing until the next second.
2. If `Changed` is higher than the last number you saw, read your settings file again and apply it.
3. For each `Action` whose number is higher than your mark, in increasing order, do the action of that key; then write your new mark in `PBZModsMenuBridge\done-<FolderName>.txt`.

At your mod's start, take the `Changed` number already in the file as seen: it is from before your mod started, and your mod reads its settings at start anyway.

### Actions

The mark file `done-<FolderName>.txt` holds the number of the last action your mod did, on a line `Action=<n>`, under a comment line if you want. Mod Panel reads it but never writes it: it drops the actions at or below your mark when it writes the signal file again. Without a mark file, your mod's mark is 0.

### Example in Lua

Copy it into your mod; the folder name comes from the script's own path. Call `Signal.second(reload, run_action)` once a second from your mod's loop, where `reload()` reads your settings file again and `run_action(key)` does the action of an action row.

```lua
-- my_mod_signal.lua: takes new settings at once, and runs actions, sent by Mod Panel or Mods Menu.
local Signal = {}

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local mod_dir = source:match("^(.*)[/\\]Scripts[/\\][^/\\]+$")      -- ...\Mods\MyMod
local name = mod_dir:match("([^/\\]+)$")                               -- MyMod
local bridge = mod_dir:match("^(.*)[/\\][^/\\]+$") .. "/PBZModsMenuBridge/"

local function encode(s)
	return (s:gsub("[^A-Za-z0-9_]", function(c) return string.format("%%%02x", c:byte()) end))
end
local EVENTS = bridge .. "events-" .. encode(name) .. ".txt"
local DONE = bridge .. "done-" .. encode(name) .. ".txt"

local function read(path)
	local f = io.open(path, "rb")
	if f == nil then return nil end
	local text = f:read(8192)
	f:close()
	return text
end

-- The signal file's text with a line end before its first line, or nil while it is missing or being written.
local function whole()
	local text = read(EVENTS)
	if text == nil or not text:find("\nEnd=1", 1, true) then return nil end
	return "\n" .. text
end

local first = whole()
local last_changed = first and tonumber(first:match("\nChanged=(%d+)")) or 0
local mark = tonumber(("\n" .. (read(DONE) or "")):match("\nAction=(%d+)")) or 0

-- Windows cannot rename onto an existing file: the old mark goes first. If the game stops in between, the mark is
-- lost and the actions still listed run again; keep your actions safe to run twice.
local function save_mark()
	local temporary = DONE .. ".tmp"
	local f = io.open(temporary, "wb")
	if f == nil then return end
	f:write("; " .. name .. ": the last action it ran.\r\nAction=" .. mark .. "\r\n")
	f:close()
	os.remove(DONE)
	os.rename(temporary, DONE)
end

function Signal.second(reload, run_action)
	local text = whole()
	if text == nil then return end
	local changed = tonumber(text:match("\nChanged=(%d+)"))
	if changed ~= nil and changed > last_changed then
		last_changed = changed
		reload()
	end
	local todo = {}
	for n, key in text:gmatch("\nAction=(%d+) ([A-Za-z0-9_]+)") do
		n = tonumber(n)
		if n > mark then todo[#todo + 1] = { n = n, key = key } end
	end
	table.sort(todo, function(a, b) return a.n < b.n end)
	for _, action in ipairs(todo) do
		run_action(action.key)
		mark = action.n
	end
	if #todo > 0 then save_mark() end
end

return Signal
```

A mod that does not read the signal file still works: it takes the new settings at its next start. Mods Menu's console command is not sent by Mod Panel 1.0.0.

## 7. If your mod has its own panel, or reads buttons itself

**One panel at a time.** Two panels open together would fight over the controller, the cursor and the game's input mode. Mod Panel and the panels that follow this rule share one UE4SS variable, `PBZ_OpenPanel`:

- It always holds text: the folder name of the mod whose panel is open, a space, then `os.time()` in whole seconds (`MyMod 1793000123`); `""` when no panel is open. Never set it to `nil`.
- A panel writes its value when it shows, again each second while it stays open, and `""` when it closes, only if the variable still holds its own name.
- Before opening, at the press and again just before showing, a panel reads the variable. If it holds another mod's name with a time 3 seconds or less from `os.time()`, either way, it does not open. Any other value counts for nothing: empty, unreadable, its own name, or an older time. A panel closed badly so blocks the others for 3 seconds only.
- The folder name may hold a space: the time is the value's last word.

```lua
-- Whether another mod's panel is open now.
local function other_panel_open(my_name)
	local ok, value = pcall(function() return ModRef:GetSharedVariable("PBZ_OpenPanel") end)
	if not ok or type(value) ~= "string" then return false end
	local owner, time = value:match("^(.+) (%d+)$")
	return owner ~= nil and owner ~= my_name and math.abs(os.time() - tonumber(time)) <= 3
end
```

**Buttons read by your mod.** While Mod Panel is open, the game hears none of the controller's buttons, nor any key it uses. A mod that reads buttons or keys itself (with `IsInputKeyDown`, for example) may still see the presses the player makes in the panel. Check `PBZ_OpenPanel` with the function above, using your own folder name, and ignore those presses while a panel is open.

## 8. Checking your files

Mod Panel writes in `platform\steam\ue4ss\UE4SS.log`, once per game and per reason, every row it leaves out and every mod it does not list. Each line starts with the time and `[Lua]`; search for `[ModPanel]` and your folder name:

```
[ModPanel] MyMod: setting Hotkey: default F13, left out
[ModPanel] MyMod: the descriptor is not JSON (...), rows from the settings file instead
[ModPanel] MyMod: the settings file is not one JSON object, not shown
[ModPanel] MyMod: no usable setting (type color), not shown
[ModPanel] MyMod: setting Strength: greyedUnless Preset, a value it cannot take, left out
```

A key or a value quoted from your files is cut to 64 characters, then `...`, and a line break or another control character in it shows as `?`.

Each time it saves your settings, Mod Panel also writes which values it changed: `[ModPanel] MyMod: settings written (Strength 2)`. Compare with what your mod says it read. When the file cannot be written: `[ModPanel] MyMod: settings not saved (the settings file is read-only, or held by another program)`.

## 9. Licence

The code and JSON examples of this guide are dedicated to the public domain under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/): copy them into your own mods, changed or not, with or without credit.

Mod Panel itself is under the [PolyForm Strict License 1.0.0](https://polyformproject.org/licenses/strict/1.0.0). Making your mod work with Mod Panel needs none of its code: you write your own files, in the format this guide describes.
