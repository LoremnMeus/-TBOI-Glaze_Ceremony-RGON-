# Qing Remaster Chinese Menu Assets

Character select, starting-room controls, and game-over names load when
`character_select` / `controls` / `game_over` are enabled in
`Qing_Remaster_scripts/translations/menu_language_manifest.lua`.
Do not set the top-level `enabled = true` until title/main ANM2 files exist.

Sync copies from `content/gfx/` with:
`D:\Apps\Miniconda\python.exe codex_work/tools/sync_menu_lang_zh.py`

Runtime ANM2 files:
- `character_menu/menu.anm2`
- `character_menu/menu_b.anm2`
- `controls/controls.anm2`
- `game_over/death_screen.anm2`

Reload command:
- `qing_menu_lang_reload`
