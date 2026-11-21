# Building the v2 zones

Everything is rebuilt with **OpenAssetTools** (Linker / Unlinker) for T6. The trick for every zone: pass the
**original** `.ff` first with `-l`, then the stock base zones. The Linker then copies every asset it doesn't find
in the search path verbatim from the original, so the search path only needs the new or changed assets.

```
B=<folder with the stock code_pre_gfx_zm.ff, code_post_gfx_zm.ff, patch_zm.ff, common_zm.ff>
Linker --base-folder "$PWD" --add-asset-search-path "$PWD/add" \
  -l src/<zone>.ff -l $B/code_pre_gfx_zm.ff -l $B/code_post_gfx_zm.ff -l $B/patch_zm.ff -l $B/common_zm.ff <zone>
```

`src/<zone>.ff` is the original file from DLC5 2.0.5 (or the stock game for `dlczm0_load_zm`). Unsigned T6 zones
only decode under their own file name, so keep the name. Always check the result with the Unlinker: dump the old
and new zone and diff them. Only the assets you meant to change may differ (and the localize order).

Pitfall: assets the mod overrides from the stock zones (`zm/mapstable.csv`, `gametypestable.csv`,
`factiontable.csv`, `clientscripts/mp/zombies/_zm_utility.csc`) are taken from the base zones unless the mod's own
dumped copy is in the search path. That's why `build/mod_load/add/` has them.

## mod.ff

`build/mod/mod.zone` = the original zone list plus 47 `script,` lines. Search path: only the 47 scripts compiled
with gsc-tool (`gsc-tool -m comp -g t6 -s pc <dir>`, from DLC5's loose `maps/`, `scripts/`, `clientscripts/`)
and the `english/` localize from an Unlinker dump. All other assets (incl. the sound bank) come from the original.

## mod_patch.ff / mod_patch.ipak

`build/mod_patch/mod_patch.zone` has `>ipak,mod_patch` (instead of `>level.ipak_read,mod_patch`), so the Linker
writes a new ipak. Then every image in the zone needs its pixels in `add/images/`: the Unlinker dump of the
original, with opaque DXT5 images converted by `tools/dxt5to1.py` (lossless: the colour block is reused, the
alpha block dropped; it refuses images with real alpha), plus `fxt_light_flare_halogen` from `common_zm`.

## mod_load.ff / mod_load.ipak

`build/mod_load/mod_load.zone` (`>ipak,mod_load`): the original assets plus the 30 v1 map-art images
(`menu_dlc5_*`, `loadscreen_*`, from the `v1` tag) with materials made from the `menu_zm_theater_map` template
(`add/materials/`). Opaque globe images converted with `dxt5to1.py`. The 9 blurred backgrounds are made with
`tools/make_blur.py <sharp map>.iwi <original blur>.iwi <out>.iwi --sigma N` (moon 24, pentagon 16, temple 16,
the rest 8).

## zone/all/dlczm0_load_zm.ff

The stock Nuketown DLC load zone plus the 11 `loadscreen_dlc5_*` images **embedded** (`image,*name` in
`build/dlczm0_load_zm/dlczm0_load_zm.zone`) and their materials (`add/materials/`). This zone stays loaded while a
map starts, unlike the mod's own zones, so the loading screens show from the first frame. Built with
`-l src/dlczm0_load_zm.ff -l code_pre_gfx_zm.ff -l code_post_gfx_zm.ff`; all stock assets stay identical.
