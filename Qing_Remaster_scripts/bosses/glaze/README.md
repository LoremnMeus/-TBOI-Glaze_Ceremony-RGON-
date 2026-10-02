# Prince of Glaze — v1 development workspace

Runtime identity: `996 / enums.Enemies.Prince_Glaze` (XML variant 23510).
Entry: `../Boss_Glaze.lua`; XML HP and all existing art remain unchanged.
This is a playable placeholder implementation, not a final art/balance pass.

## Modules

| Module | Responsibility |
| --- | --- |
| `glaze_controller` | Three phases, threshold clamps, transitions, weighted scheduler, cleanup |
| `glaze_attacks` | 4 Crown + 4 Palace + 4 Shattered attacks, 3 Finale variants |
| `glaze_geometry` | Four preset reflections, swept intersection, tactical positions |
| `glaze_mirror` | Mirrors, maximum two bends, one fixed field rotation |
| `glaze_shard` | Hostile projectiles, crown 5-stack/6–8–10–12–16 visual vocabulary |
| `glaze_placeholder` | Harmless Tear objects, labels and warning paths |
| `glaze_visual_assets` | Shared Crown / Shard / Palace anm2 paths (no gameplay state) |
| `glaze_palace` | Procedural palace build/stability/anchors (visual + spatial, not an attack) |
| `glaze_story_adapter` | Five material labels from Story definitions; guarded victory hook |
| `glaze_debug` | Practice controls + Boss Test adapter + console `glaze …` |

No player Crown item dependency; no player stack/cache/Seija state is shared.
Boss and Item may share `glaze_visual_assets` paths only — never `require` the Item module.
All modules preload at startup; callback registration stays in the existing enemy manager.
Entity maps use pointer hashes or local object IDs, never userdata keys.

## Test controls

**Debug → Boss Test → 琉璃王子** is the canonical combat lab:

- Encounter: spawn / restart / cleanup / kill (practice)
- State: Force P1 / P2 / P3 / Finale (instant, no transition playback)
- HP slider + 66/65/33/32/11/10% buttons (does not force phase)
- Performance: Play T1 / T2 / Finale (production transitions)
- Attacks / Palace / Freeze+Step / Inspector

Story Test (`chapter1.glaze_boss`) remains for **narrative** prepare/enter only.
Practice spawn/kill never grants permanent completion marks.

Console alternatives:

```text
glaze spawn
glaze restart
glaze phase 1
glaze transition 1
glaze phase 2
glaze attack p2.kaleidoscope
glaze transition 2
glaze phase 3
glaze finale
glaze hp 0.66
glaze freeze
glaze step 10
glaze palace preview
glaze palace build 1
glaze palace stab 0
glaze next
glaze reset
glaze inspect
glaze clear
glaze labels
glaze kill
glaze cleanup
```

## Clocks and guardrails

- All attack/transition timers advance in `MC_POST_UPDATE`: 30 Hz.
- Thresholds: 65%, 32%; transitions ~150f/210f, damage blocked during transitions.
- Finale remains phase 3 at 10%; no extra health bar or armor.
- Crown shards in P1 always number five; each locks a position before firing.
- Transition 1 crown debris are visual-only sprites (not projectiles).
- Palace is visual/spatial infrastructure: build 0→1 on T1, stability 1→0 on T2, remnants in P3.
- P2 mirror/echo/kaleidoscope prefer Palace anchors with hard-coded fallbacks.
- Placeholder Tears have zero damage/collision and cannot end a Dead Eye streak.
- Warning lines remain enabled when labels are hidden; public builds default labels off.

## Local verification

```text
npm exec --yes --package=fengari-node-cli@0.1.0 -- fengari scripts/dev/test_glaze_boss.lua
```

Run from the mod root. The test compiles touched Lua files and exercises attacks /
geometry with a mocked Isaac environment. In-game Boss Test Lab remains required for
palace / crown art / freeze / HP-threshold regression.
