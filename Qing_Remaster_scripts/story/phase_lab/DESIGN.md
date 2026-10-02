# Phase Lab — Design Contract (V1)

## Scope

Phase Lab covers only:

Discover → Calibrate → Insert materials → Activate Phase Anchor.

V1 does **not** implement Interstice rooms, Reverse Qing, Futurization, or Glaze Final Alchemy.

## World rule

The Phase Anchor does **not** create a third world and does **not** open the Calamity world directly.

It anchors reality onto the thin boundary between two worlds (the Interstice). Interstice content lives outside this module.

## Hard rules

1. Puzzle is **NOT** physics Sokoban. Pieces use discrete logical states only.
2. Runtime puzzle state is authoritative; entity position is presentation.
3. `RESET` never clears permanent `puzzle_solved`.
4. `RESET` never removes inserted materials.
5. Permanent completion means later visits spawn the solved layout by default.
6. Replay mode is runtime-only (`StoryRun.phase_lab.puzzle.replay_mode`).
7. Puzzle / Materials / Anchor stay separate modules; `controller` coordinates.
8. Do not implement Interstice content inside Phase Lab modules.
9. Lab visual language is tombstone + alchemy (brass / stone / runes). Avoid futuristic neon.
10. Catalyst availability: prologue completed (formal) or `StoryRun.phase_lab.debug_catalyst` (debug only). **Never** grant Catalyst from `phase_lab.discovered`.
11. `chapter1.material.phase_anchor` is a **calibration / machine-ready** progress token for 5/5 accounting — not a portable "Phase Anchor Core" ingredient. Player copy must say calibration, not "obtain a core".

## Permanent (`StoryProgress.phase_lab`)

```lua
{
  discovered = false,
  puzzle_solved = false,
  anchor_activated_once = false,
}
```

## Runtime (`StoryRun.phase_lab`)

```lua
{
  room_initialized = false,
  overlay_force = false, -- debug teleport into current room
  puzzle = {
    active = false,
    replay_mode = false,
    states = { A=0, B=0, C=0, D=0, E=0, F=0 },
    solved = false,
    transitioning = false,
  },
  materials = {
    property_1 = false,
    property_2 = false,
    property_3 = false,
    property_4 = false,
    catalyst = false,
  },
  anchor = { state = "idle" }, -- idle | ready | activating | open
}
```

## Acceptance (V1)

Mausoleum boss clear → lab door → enter lab → misaligned 6-piece puzzle →
solve → slots appear → insert 4P+Cat → Anchor READY → activation stub.

## Tests

See `test.lua` and Story Dev → Phase Lab panel.
