# Changelog

Public Alpha notes for Glaze Ceremony: Promised Land. This file belongs to the
public GitHub repository overlay; it is not shipped inside the player ZIP.

## alpha-0.1.2

### Fixed

- Zeis notice boards keep gray dogma noise. The sign no longer stays blue from a negative red/green color offset.
- Greed bank loans and cash trades commit only when the full coin amount arrives.
- A Bard Beggar that has already been paid resumes into its exit.

### Added

- Greed bank collateral is chosen on the terminal, in pages of sixteen.
- Upright Thoth cards can draw one reverse face from the normal pool.

## alpha-0.1.1

Fixes for Glowing Hourglass and native `rewind` restoring room-linked state.

### Fixed

- Death Field ghosts now reappear in the restored room after Glowing Hourglass.
- Native console `rewind` under REPENTOGON now restores the previous room’s
  run state (including Wizard portals) instead of an older leftover snapshot.
- Hourglass and `rewind` now share the same player-identity rebind before
  restoring rewindable run state.

Hourglass / rewind still do not restore Chapter 1 story (not present in this
alpha).

## alpha-0.1.0

First public alpha test of the remastered project.

**Current story content ends after the Prologue.** Chapter 1 is not available
in the normal play flow.

### Added / Reworked

- Prologue story
- Current remastered item/card content (original Glaze Ceremony items and cards,
  plus currently finished rework)
- Character remaster and compatibility work in progress (not a finished
  character pass)
- Quest / story infrastructure
- Current UI and system rebuilds

### Current limitations

- Story ends after the Prologue
- Chapter 1 is not available
- Character remaster fine-tuning is not complete; Tainted Qing currently has
  basic vanilla-item compatibility only (aircraft skins and this mod's custom
  item/mechanic compatibility are still incomplete)
- Alpha builds may contain incomplete visuals, balance and compatibility issues
