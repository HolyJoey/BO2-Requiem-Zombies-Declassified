# Zombies Declassified (DLC5) for BO2 Requiem – Switch and Android

**Zombies Declassified 2.0.5** (the DLC5 port by **Logo2K**, with **Fr0sty**'s BETA 2 patches), fixed so it runs properly on Black Ops II through **Requiem**: **Requiem NX** on the Nintendo Switch and **T6Requiem** on Android.
All credit for Zombies Declassified goes to Logo2K, Fr0sty and everyone in their credits. This version adds the fixes needed to make it work on Requiem.

Tested on Requiem NX 0.3.2 (Switch) and T6Requiem (Android).

## Download

**[Full DLC5 (`DLC5_v2_Full.zip`)](https://drive.proton.me/urls/2WMDZGE3H8#HQTMMKQn2KUH)**: the complete mod with all fixes included, for Switch and Android.

**Have the Discord version (`Requiem_DLC5.zip`, Nov 11)?** The small `DLC5_v2_Update.zip` (56 MB) in [Releases](../../releases) is enough; see the release notes for the steps.

## Install

The zip contains a `t6game` folder. Extract it into the folder that **holds** your `t6game` folder, so it merges into the existing one, and let it replace existing files:

- **Switch:** the `switch` folder on the SD card → `switch/t6game/`
- **Android:** the `Download` folder → `Download/t6game/`

Nothing outside `t6game/mods/dlc5/`, `t6game/usermaps/` (the 9 DLC5 maps) and `t6game/zone/all/dlczm0_load_zm.ff` is changed.

### New install (no DLC5 yet)

1. **Back up** `t6game/zone/all/dlczm0_load_zm.ff`. DLC5 replaces this game file; you need the original to go back.
2. Extract the zip as described above.
3. Empty `t6game/script_cache/` (the game rebuilds it).
4. Start BO2, open **Mods** and pick **Zombies Declassified**. The first map load is slower once.

### Already have the Discord version (`Requiem_DLC5.zip`, Nov 11) or an older DLC5

1. **Back up** `t6game/zone/all/dlczm0_load_zm.ff`.
2. Extract the zip as described above.
3. **Delete these by hand** (extracting can't delete files, and the old copies get in the way):
   - `t6game/mods/dlc5/maps/`
   - `t6game/mods/dlc5/scripts/`
   - `t6game/mods/dlc5/clientscripts/`
   - `t6game/mods/dlc5/mods.iwd` (if you have it)
   - `t6game/images/loadscreen_dlc5_*.iwi` and `t6game/images/menu_dlc5_*.iwi` (30 files, if you have them)
   - everything inside `t6game/script_cache/` (the game rebuilds it)

   Only delete what is listed. Your other mods and scripts are not touched.
4. Start BO2, open **Mods** and pick **Zombies Declassified**. The first map load is slower once.

## What is fixed

| Problem | Fix |
|---|---|
| Game closes when you open **Kino**'s map screen (UI Error 80076) | Extra start locations are only added when the menu has a position for them. |
| Game closes when you **open the scoreboard, die or end the game** | `Engine.GetCustomTeamName()` returns `nil` on Requiem; added a `nil` check. |
| **Main menu stuck** (no buttons work) after backing out of a lobby | A safety net turns input back on when the menu is left locked. |
| **Checkerboard** on the DLC5 loading screens | The loading screens live in a load zone that stays loaded all session, so the artwork shows from the first frame. |
| **Raw map name** on the loading screen (`zm_cosmodrome`) | Replaced with DLC5's own names ("ASCENSION GROUP FACILITY"). |
| **Raw lobby options** (`MENU_MINPLAYERS_CAPS` …) | Now MIN PLAYERS, CHEATS and PERMA PERKS. |
| Moon's **No Man's Land** start can't be selected | Selectable again, with its own map art and loading screen. |
| Kino's **stage** start (Grief / Turned) can't be selected | Selectable again. |
| Old map art | The new 2.0.5 map-screen art for Kino, Moon, Five, Ascension and Shangri-La. |
| **Blocky** blurred background behind the map screen and lobby | New smooth blurs for all 9 maps, same look without the blocks. |
| Map art and loading screens missing **on Android** | Android doesn't load loose images, so all art is built into the mod's zones. One install for both platforms. |
| DLC5 maps load slowly | No `mods.iwd` (~20 s faster per map), the 47 scripts come precompiled inside `mod.ff`, and smaller menu textures. |

**Why most of this was needed:** in the menu, Requiem only loads a mod's `mod_load.ff`; `mod.ff` and `mod_patch.ff` load when a map starts. DLC5 2.0.5 put its new menu content (game-mode table, map art, lobby texts) in `mod_patch.ff`, so the menu never saw it.

### Changes compared to Logo2K's and Fr0sty's 2.0.5

- **`mods/dlc5/ui/t6/mainlobby.lua`**: no crash on missing start spots, the Moon/Kino start rows the menu was missing, the new map art, and the stuck-menu fix.
- **`mods/dlc5/ui_mp/t6/hud/scoreboard.lua`**: the `nil` team-name crash; loading screens and map names.
- **`mods/dlc5/ui_mp/t6/menus/privategamelobby_project.lua`**: readable lobby option names.
- **`mods/dlc5/mod.ff`**: the 47 loose scripts (`maps/`, `scripts/`, `clientscripts/`) compiled with gsc-tool and stored inside; the script code is unchanged. Requiem no longer compiles them on the first load.
- **`mods/dlc5/mod_load.ff` + `.ipak`**: the new map-screen art and its materials built in, opaque images stored as DXT1 (same pixels, half the size), and new smooth blurred backgrounds. The game shows only the centre quarter of those, zoomed ~2.5×, so the old ones looked blocky.
- **`mods/dlc5/mod_patch.ff` + `.ipak`**: same assets, opaque images stored as DXT1 (19 → 13 MB).
- **`zone/all/dlczm0_load_zm.ff`**: a stock DLC load zone (all stock assets identical) with the 11 DLC5 loading screens added. It stays loaded while a map starts, unlike the mod's own zones.
- **Removed:** `mods/dlc5/mods.iwd`. Requiem never loads the scripts inside it, but any `.iwd` in a mod folder switches off Requiem's fast image lookup, so every map loaded about 20 seconds slower.

## Going back

Restore your backup of `zone/all/dlczm0_load_zm.ff` and delete `t6game/mods/dlc5/`.

## Credits

- **Zombies Declassified** by **Logo2K**: https://github.com/Logo-2K/zombies-declassified (GPL v3). The precompiled scripts in `mod.ff` are compiled unchanged from the 2.0.5 scripts.
- **BETA 2 patches** by **Fr0sty**: https://github.com/Fr0styProductions/Zombies-Declassified-Patches (MIT, see `licenses/Fr0sty-patches-MIT.txt`). Fr0sty asks for credit in videos made with the patches: "@fr0sty_7952 on Youtube, @fr0s_ty_ on Discord".
- Everyone in [Logo2K's credits](https://github.com/Logo-2K/zombies-declassified/blob/main/CREDITS.md): Kevin Sherwood (music), Plutonium, OpenAssetTools (Laupetin and contributors), GabsPuNs (BO2 X360 Patches), NickB_05 (menu art), Ronan (shader/icon art).
- **BO2 Requiem NX** by HDErick: https://github.com/HDErick/BO2-Requiem-NX
- **gsc-tool** (xensik) for compiling the scripts.
- Call of Duty: Black Ops II and all game assets: Treyarch / Activision. Fan project, not affiliated with or endorsed by Activision.

## License

The scripts in this mod are based on Zombies Declassified and are released under the **GNU GPL v3**, the same as the original (see `LICENSE`).
