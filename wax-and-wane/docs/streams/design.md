# Stream notes: design (game design and feel pass)

Branch `revamp/design`. The reasoning, the data and the before/after numbers are in
`docs/design/MDA.md`; this page is the integrator's list.

## What changed
- **Input feel** (`player.gd`): a fire press in the last 0.2 s of the recharge fires the moment the
  flame is ready (`FIRE_BUFFER`); turning back from a run brakes at `TURN_ACCEL` 2600 (was 900).
  `hud.gd`: the touch aim stick is a direction past a 4 px flick (`AIM_FLICK`; it used to need 6.6 px).
- **Fair deaths**: enemy orbs got a hot core (`tools/art_hero_fx_items.py` ORB), the wax bolt a cream
  core (`tools/art_monsters.py`), the cog bolt a gold body (`tools/art_tower.py`); red and pink
  telegraph dots alternate with a gold / cream dot (`telegraph.gd` `HOT`).
  `tools/design_bullets.py` rebuilds only those sprites (the full tools rebuild much more).
- **Wax prices on the wax bar** (`hud.gd` `preview_cost(now_min, max_min)`): marching red over the wax
  a price cuts now, marching soot over the minutes it chars for good. Called by `pickup.gd` (altar and
  mirror relics, `Pickup.pact_cut()` = the real rule) and `specials.gd` (`_preview_costs`: the font,
  the mirror's toll mark).
- **Share button** on the results screen (`results.gd` -> `scripts/ui/share.gd` `Share.text/copy`).
- **Floor 1 opening** (`floor_gen.gd`): ordinary rooms within 2 of the start are easy layouts (2-3 slots,
  open/cover/furniture); the first two fought call only slow lodgers (`FloorGen.OPENING_POOL`, no marked
  foes; `world.gd` `_spawn_room_enemies` asks `FloorGen.opening_now`); a treasure room within 3 rooms.

## Hooks other streams should know
- `hud.preview_cost(now_min, max_min := 0.0)`: call every frame while a wax price is in reach.
- Cell data on floor 1 may carry `"opening": true` and `"tpl": "<template id>"`.
- `FloorGen.tier_of(cell)` / `tier_of_template(t)`: "easy" / "normal" / "hard".
- Telegraph colours `#da4e38` and `#f78697` now draw every other dot in their hot partner.

## Judges (all headless unless noted)
- `godot --headless --path . -- --autotest --designcheck` runs latency, share and floors; each prints PASS/FAIL.
- `xvfb-run ... -- --autotest --designcheck --floorshots --shots=DIR` then `python3 tools/design_contrast.py DIR`.
- `xvfb-run ... -- --autotest --designcheck --ghostshot --shots=DIR` then `python3 tools/design_ghost_check.py DIR`
  (also presses Share on a results screen and reads the clipboard back).
- `python3 tools/design_playtest_summary.py logs...` sums `--playtest` logs (win rate, finish clock,
  floor-1 hits, hits per minute by floor, where shots came from). The playtest `[diag]` now also
  names hazards (`via spikes`, `via hearth`, `via bomb`), shot origins, and floor 1's rooms in order.

## Credits
No new assets from outside; every change is made by the repo's own tools and code.
