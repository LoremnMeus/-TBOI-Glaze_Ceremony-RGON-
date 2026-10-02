# Item legacy archive

Runtime cutover for Suture Needle completed. Legacy pixel-suture source no longer lives under `Qing_Remaster_scripts` (publish tree).

| Archive path | Meaning |
|--------------|---------|
| `codex_work/archive/Item_Suture_Needle_pixel_suture.lua` | Pre-Runtime-Stitch Suture Needle: alpha-mask wound placement, dual-edge threads, corpse stitch densify. Historical/reference only. |

Hard rules:

- This implementation must not be required by gameplay code.
- Do not patch bugs or add synergies here.
- Current entry: `Qing_Remaster_scripts/items/Item_Suture_Needle.lua`
- Runtime Stitch: `others/runtime_stitch_pair.lua` + `auxiliary/native_mixture/controller.lua` + `runtime_stitch_visual_adapter` + `sprite_splice`（shell Friend 已归档）
