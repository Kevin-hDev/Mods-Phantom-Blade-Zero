# Mods Phantom Blade Zero

Movement and camera mods for Phantom Blade Zero, and an in-game settings panel, written in Lua for UE4SS.

| Mod | What it does | Version |
|---|---|---|
| [Jump Strafe](jump_strafe/) | Steer your character in the air during jumps and falls, with the movement keys or the controller's left stick | 1.0.0 |
| [Tap Strafe](tap_strafe/) | Mid-jump, your character follows the camera as you turn it, with the mouse or the controller's right stick | 1.0.0 |
| [Dodge Jump](dodge_jump/) | A double and triple jump in the air with the game's own dodge animations, and a jump that goes off right after landing | 1.0.6 |
| [Dynamic FOV](dynamic_fov/) | A field of view that follows your movement, one per situation (walking, sprinting, crouching, combat), each with its own camera position, with six cinematic looks | 1.0.11 |
| [Movement Tuning](movement_tuning/) | Faster or slower moves and attacks, each on its own or all at once, higher jumps, the stick's curve, automatic or toggle sprint, stops without sliding, the sprint resumed after a move, faster dodge landings, the high-speed sprint's delay, the sprint turned off if you want, a realism setting: no sideways glide in turns, smooth slowdowns, heavier starts, and enemy speeds too | 1.0.6 |
| [Slide Anywhere](slide_anywhere/) | Slide anywhere, on flat ground, downhill and uphill, with the game's own slide animation | 1.0.0 |
| [Mod Panel](mod_panel/) | An in-game panel for the settings of every UE4SS mod, with a controller or with keyboard and mouse, in 15 languages | 1.0.4 |
| [Vault & Climb Anywhere](vault_climb_anywhere/) | Vault over and climb onto the obstacles the game refuses, up to 5 m high, with the game's own animations (beta) | 1.0.0 |

Each folder holds the mod exactly as it ships on Nexus Mods: its `platform` folder (and, for Mod Panel, its `ProjectPBZ` folder) mirrors the game folder. Mod Panel's folder also holds its README and its guide for mod authors, in [English](mod_panel/MOD-AUTHORS.md) and [Simplified Chinese](mod_panel/MOD-AUTHORS.zh-CN.md).

## Installing a mod

1. Install [UE4SS for Phantom Blade Zero](https://www.nexusmods.com/phantombladezero/mods/13).
2. Optional: [Mod Panel](https://www.nexusmods.com/phantombladezero/mods/898), or [Mods Menu](https://www.nexusmods.com/phantombladezero/mods/149) with its optional file "UE4SS Bridge", to change the settings in game. Each mod's Nexus page says which versions it needs.
3. Close the game, then copy the mod's folders (`platform`, and `ProjectPBZ` for Mod Panel) into the game folder, the one that contains `platform` and `ProjectPBZ`.

## Reporting a problem

Report it in the Bugs tab of the mod's Nexus page, and say what you were doing when it happened, where you were, and which version of the game and of the mod you are on.

## License

Every mod in this repository but Mod Panel is under the [GNU General Public License v3.0](LICENSE). Copyright 2026 Kevin-hDev.

You may use, change and share this code, in your own mods too. A mod that uses this code must be under the GPL-3.0 as a whole, with its source available. Game assets, UE4SS and Mods Menu are not relicensed by this repository.

Mod Panel is under the [PolyForm Strict License 1.0.0](mod_panel/LICENSE): you may download it and use it for your own play, for free; you may not share it elsewhere, sell it, or change its code, unless Kevin-hDev allows it. The code and JSON examples of its guide for mod authors are free to copy into your own mods (CC0 1.0).
