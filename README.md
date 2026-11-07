# Mods Phantom Blade Zero

Movement and camera mods for Phantom Blade Zero, written in Lua for UE4SS.

| Mod | What it does | Version |
|---|---|---|
| [Jump Strafe](jump_strafe/) | Steer your character in the air during jumps and falls, with the movement keys or the controller's left stick | 1.0.0 |
| [Tap Strafe](tap_strafe/) | Mid-jump, your character follows the camera as you turn it, with the mouse or the controller's right stick | 1.0.0 |
| [Dodge Jump](dodge_jump/) | A double and triple jump in the air with the game's own dodge animations, and a jump that goes off right after landing | 1.0.6 |
| [Dynamic FOV](dynamic_fov/) | A field of view that follows your movement, one per situation (walking, sprinting, crouching, combat), with an in-game panel | 1.0.6 |
| [Movement Tuning](movement_tuning/) | The speed of each move and attack on its own or all at once, higher jumps, the stick's curve, automatic sprint, the sprint resumed after a move, faster dodge landings, and the sprint turned off if you want | 1.0.2 |
| [Slide Anywhere](slide_anywhere/) | Slide anywhere, on flat ground, downhill and uphill, with the game's own slide animation | 1.0.0 |

Each folder holds the mod exactly as it ships on Nexus Mods: its `platform` folder mirrors the game folder.

## Installing a mod

1. Install [UE4SS for Phantom Blade Zero](https://www.nexusmods.com/phantombladezero/mods/13).
2. Optional: [Mods Menu](https://www.nexusmods.com/phantombladezero/mods/149) with its optional file "UE4SS Bridge", to change the settings in game. Each mod's Nexus page says which versions it needs.
3. Close the game, then copy the mod's `platform` folder into the game folder, the one that contains `platform` and `ProjectPBZ`.

## Reporting a problem

Report it in the Bugs tab of the mod's Nexus page, and say what you were doing when it happened, where you were, and which version of the game and of the mod you are on.

## License

Every mod in this repository is under the [GNU General Public License v3.0](LICENSE). Copyright 2026 Kevin-hDev.

You may use, change and share this code, in your own mods too. A mod that uses this code must be under the GPL-3.0 as a whole, with its source available. Game assets, UE4SS and Mods Menu are not relicensed by this repository.
