# Mod Panel

An in-game settings panel for every UE4SS mod of Phantom Blade Zero. Open it while you play, change any mod's settings with the controller, the keyboard or the mouse, and close it: the game never leaves the screen.

## What it does

- **Every UE4SS mod in one panel.** Mod Panel lists the mods UE4SS runs that have settings, and shows each setting as the game's own menus do: switches, lists, bars, key and button choices, buttons for actions.
- **Made for the controller.** Every command works with a PlayStation or Xbox controller, with the buttons shown as their icons, and also with the keyboard and the mouse.
- **The game keeps running behind it**, or freezes while the panel is open if you turn `Freeze game` on.
- **A short list.** By default, only the mods that are on show; check `Mod disabled` to see the others.
- **Favorites first.** Mark the mods you change most: they move to the top of the list, their diamond lit, even after you restart the game.
- **Every mod off in one press.** `All mods`, at the top of the list, turns off every mod that has an on/off switch (its `Enabled` setting), Mod Panel excepted, and later turns back on only those, even after you restart the game.
- **Explanations in their own column**, which you can hide.
- **Sections that fold**, and settings greyed while another setting makes them useless, when the mod's author asks for it.
- **In the game's 15 languages**, or the one you choose.
- **Two ways to navigate**: `Classic` (the list of mods, then a mod's page) or `Hybrid` (straight to the settings).
- **Mods Menu is not needed.** Mod Panel reads the same files: the UE4SS mods made for Mods Menu show in Mod Panel too, and both can stay installed. The JavaScript mods made for Mods Menu need it to run; while it runs them, Mod Panel shows their settings too, except their action buttons.

## Requirements

[UE4SS for Phantom Blade Zero](https://www.nexusmods.com/phantombladezero/mods/13).

## Installing

1. Close the game.
2. Copy the `platform` and `ProjectPBZ` folders of the archive into the game folder, the one that already contains a `platform` and a `ProjectPBZ` folder.

To remove it, close the game and delete `platform\steam\ue4ss\Mods\ModPanel` and `ProjectPBZ\Content\JavaScript\PBZModsMenu\Mods\AAModPanelLink`.

## Opening and closing

| | Opens and closes |
|---|---|
| Keyboard | F1 |
| PlayStation controller | Create, the button left of the touchpad |
| Controller combination | Two buttons pressed together, of your choice; none by default |

**Xbox controller:** it has no Create button, and the game uses all its other buttons. Open the panel with F1, or choose a button in `Controller button` or a pair in `Controller combination`, on Mod Panel's own page.

The panel opens only in play: not in a cutscene, a loading screen or one of the game's menus. It closes by itself when a cutscene starts, an area loads, the character changes or one of the game's menus opens. Only one settings panel shows at a time: Mod Panel does not open while another mod's own panel is open, Dynamic FOV's for example.

## Controls

`Classic` navigation, the default:

| Controller | Keyboard | Action |
|---|---|---|
| D-pad or left stick | Arrows | Move up and down; left and right change the value |
| Cross | Enter | Open the selected mod's page; in a page, choose |
| Circle | Escape | In a page, back to the list; in the list, close |
| L1 / R1 | Z / C | Previous / next mod |
| L2 / R2 | | First / last setting of the page |
| Triangle | R | `Restore defaults`, then `Undo` |
| Square | X | Hide or show the explanations |
| R3 | F | Mark or unmark the mod as a favorite |
| Create | F1 | Close |

In the list of mods, Right also marks the selected mod as a favorite, and Left unmarks it.

With the mouse: point at a setting, click it or its arrows, drag a bar, and scroll with the wheel; click a mod's diamond to mark or unmark it.

`Hybrid` navigation, on Mod Panel's page, goes straight to the mod's settings: up and down move through them, L1 and R1 change the mod, R3 or F marks it as a favorite, and Circle or Escape close.

- **Choosing a key or a button:** press Cross on the setting, then the key or the button you want. Escape cancels.
- **Actions** ask for two presses: the first one arms the button ("Press again"), the second one sends it.
- **Sections:** select a section's title and press Cross, Enter, Left or Right, or click its "Show" or "Hide", to fold it or open it. Sections stay as you left them, even after you restart the game.
- **Greyed settings** wait for another setting: select one to read which, for example "Set Preset to Custom to change this row."
- **Restore defaults** puts every setting of the mod that has a default back to it, keys and buttons included; a key that another setting already uses stays as it is. `Undo`, right after, brings them all back.

## Your changes

Mod Panel saves a mod's settings half a second after your last change, and when you switch mods or close the panel. Most mods take the change at once; a mod that does not listen for it takes it at its next start, and a setting marked "Applies after a restart" needs one.

Mod Panel's own settings, on its page in the panel: `Navigation`, `Panel key`, `Controller button`, `Controller combination`, `Button icons` (`Auto` follows the controller in use, or `PlayStation`, `Xbox`), `Language` and `Background color` (the panel's background in one of ten colors). `All mods`, `Freeze game` and `Background` sit at the top of the list of mods. All these settings are kept in `ModPanel.config.json`; the list's filter, the hidden column, the last mod opened, the mods `All mods` turned off, your favorites and the sections you folded or opened are kept in `ModPanel.state.json`, both in `platform\steam\ue4ss\Mods\ModPanel`.

Mod Panel's texts are in the game's 15 languages: English, German, Latin American Spanish, Spanish, French, Italian, Japanese, Korean, Brazilian Portuguese, Portuguese, Russian, Thai, Vietnamese, Simplified Chinese and Traditional Chinese. `Language` on Mod Panel's page chooses: `Game` follows the game's language, or pick one. Each mod's own texts show in that language when its author wrote it, else in English.

## For mod authors

A mod that shows its settings in Mods Menu shows them in Mod Panel too, with nothing to change. The whole format, and how a mod takes a change at once, are in [MOD-AUTHORS.md](MOD-AUTHORS.md) ([简体中文](MOD-AUTHORS.zh-CN.md)).

## Reporting a problem

Report it in the Bugs tab of Mod Panel's Nexus page: say what you were doing, which mod's page was open, and which version of the game and of Mod Panel you are on. Attach `platform\steam\ue4ss\UE4SS.log` from that session: Mod Panel writes there what it did, on lines that contain `[ModPanel]`. The game rewrites this file at each start, so copy it before you play again.

## License

Mod Panel is under the [PolyForm Strict License 1.0.0](LICENSE). Copyright 2026 Kevin-hDev.

You may download Mod Panel and use it for your own play, for free. You may not share it elsewhere, sell it, or change its code, unless Kevin-hDev allows it. The code and JSON examples of [MOD-AUTHORS.md](MOD-AUTHORS.md) are free to copy into your own mods (CC0 1.0).
