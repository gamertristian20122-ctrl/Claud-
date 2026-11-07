# Relics stream (v2.0): relics, tonics, keepsakes, rites, costumes

## What changed
- **64 relics** (24 old + 40 new). Each has `name`, `desc`, a quality tier `q` (0 to 4) and `pools`
  (`treasure`, `shop`, `boss`, `altar`, `hollow`) in `Items.RELICS`.
- `world._next_relic()` now returns `RelicFx.next_relic(self)`: a weighted pick from the relics not yet
  offered. The pool comes from the room you are in (treasure, shop, boss, Smoke Altar = boss room with
  `data.altar`, hollow = secret room). Weights by tier `[10, 8, 5.5, 3, 1.4]`, tier 3+ rises 20% a floor,
  boss and altar pools favour high tiers, shops favour low ones. It uses `world.rng`, so Tonight's Candle
  stays the same for everyone. `Items.EXCLUSIVE` keeps the Blowlamp and the Stove Door apart.
- **Unlabelled tonics**: all eight 0x72 flasks (`flask_*`, `flask_big_*`) are tonics. Each run they map to
  eight of 13 draughts (five good, two bad, one odd), seeded by `hash("%d:tonics" % run_seed)`. They read
  "Unlabelled Tonic - ???" until drunk, and are known for the rest of the run after that. Big flasks are
  1.8x stronger, for better or worse.
- **4 new keepsakes**: Censer (poison every foe), Oil Jug (a pool of burning oil), Music Box (every foe is
  charmed for 4 s), Hand Mirror (enemy shots near you turn back for 3 s).
- **2 new rites**: Rite of the Household (helpers: a second Matchling, helpers x1.5) and Rite of the
  Seance (curses: double chance, longer). The Hearth, Clock and Many Wicks rites also gained new members.
- **Costumes** (`scripts/game/costumes.gd`, a child of the Player): glass chimney, tin reflector, pipe
  with smoke puffs, knitted scarf (Wax Coat), lace collar, copper wire, red-hot drips, a ghost-pale
  body (Pale Taper), wind-up key, pink bow, jet brooch (glints while charged), nightshade sprig, phoenix
  feather (gone once used), a second flame (Lit at Both Ends), an apron (Household) and orbiting wisps
  (Seance).

## The 40 new relics
| Kind | Relics |
|---|---|
| Shot modifiers | Split Wick (3 sparks on hit), Tin Sconce (2 wall bounces), Old Pipe (smoke-ring boomerang), Warming Pan (3 orbiting coals), Lace Fan (+2 fanned shots), Bell Wire (chain spark to 2 more foes), Stove Door (hold to charge), Wick Trimmer (1 in 5 crits x3), Fire Tongs (stagger + knockback) |
| Showcase attacks | Blowlamp (a flame jet that also eats bullets), Pale Taper (ghost shots through walls and foes), Tinderbox (every shot becomes seeking sparks) |
| Curses | Cold Wax (slow: hard wax round the feet), Shadow Puppet (fear), Love Letter (charm: fights for you), Nightshade (poison that spreads on death) |
| Helpers | Matchling (follows and shoots), Paper Lantern (orbits, blocks shots), Dust Bunny (bites foes, fetches coins), Clockwork Mouse (wind-up mice that pop) |
| Defence | Thimble (20% dodge), Scalding Wax (burns whatever hurts you), Salt Line (2 s safe in a new room), Glass Chimney (a shield that regrows every 20 s), Stopped Clock (a hit freezes the house 1.5 s) |
| Finding things | House Deed (full map), Dowsing Rod (hollows on the map + a shimmer on the cracked wall), Lodestone (magnet), Pantry Key (more and fuller chests), Collection Plate (coins per room), Sweep's Brush (drops fly to you after a clear) |
| Clock | Pendulum (the house slows below 30 wax), Bell Rope (+5 min per boss), Cuckoo Clock (+2 min and a spark ring every quarter hour), Minute Hand (+4 s per kill), Lit at Both Ends (+40% damage, melt 25% faster) |
| Odds and ends | Powder Tin (+2 bombs, blasts leave burning ground), Honeycomb (more wax drops, +15% wax), Magpie's Nest (+4% damage per relic held), Jet Brooch (after a hit, 6 shots at x2) |

## Safety caps
No split shards or extra sparks past 80 live player shots; at most 36 Tinderbox sparks; 90 flame-jet
particles; one of each helper (two Matchlings with the Household rite, two mice at a time). Bosses
are never feared, charmed or stunned; they get a half-length slow instead.
`--autotest --playtest --god --stress` hands out a random relic in every room, so a run ends holding
all 64 at once. It ran clean.

## Hooks in other people's files (one line each)
- `player.gd`: `_ready` adds `Costumes.new()`. `_fire`: `if RelicFx.before_fire(self, dir): return` at the top
  and `RelicFx.after_fire(self, dir)` at the end. `hurt`: `if RelicFx.on_hurt(self, amount, from_dir): return`.
- `shot.gd`: wall hit `if RelicFx.shot_wall(self): return` (bounce, ghost); enemy hit `RelicFx.shot_hit(self, e)`.
- `world.gd`: `_on_enter_room` `RelicFx.on_enter_room(self)`, `_clear_room` `RelicFx.on_clear(self)`,
  `_next_relic` `return RelicFx.next_relic(self)`, `on_enemy_killed` `RelicFx.on_kill(self, e)`,
  `shoot_player` `RelicFx.on_shot_made(s, p)` (before `add_child`), `_explode` `RelicFx.on_blast(self, pos)`.
- `hud.gd`: the pause relic row is up to 304 px wide (16 icons a row); hollows have a pink minimap mark.
- `results.gd`: the relic row is a centred `HFlowContainer` (18 a row).
- `autotest.gd`: `--relics=a,b,c`, `--keepsake=id`, `--stress`, and `--tour --relictour` (costume line-up,
  curse line-up, helpers, Blowlamp, pause, shop, treasure, results).

## Notes for the other streams
- **juice** (player.gd / shot.gd): keep the hook lines when you restyle `_fire` and the hit/wall code.
  `RelicFx` swaps `Shot.spr.sprite_frames` (ghost, ring, spark, big flame) and reads `Shot.vel`, `dmg`,
  `life`, `pierce`, `radius`, `_hit`, `_dead`, `end()`. Costumes reads `Player.body_height()`, `body_w`,
  `_bob`, `self_modulate`, `relics`, `rites`, `revives`, `light`, and sets `c_hi`/`c_wax`/`c_sh`/`c_deep`
  (Pale Taper). If the body geometry changes, adjust `Costumes._geo()`.
- **bestiary** (enemy.gd): curses use only `alive`, `active`, `boss`, `speed`, `radius`, `half_h`, `kvel`,
  `spr`, `_move()`, `_damage()`, `take_hit()`, `set_physics_process()`, and `modulate` (the status tint),
  plus `_flash`/`mat` when they are there. Slow = the foe's physics runs every other frame; fear/stun =
  physics off while RelicFx moves it; charm = `active = false` while RelicFx steers it into its friends.
  Any new AI works with all of them. Please don't use `Enemy.modulate` for something else.
- **platform** (save & continue): save `player.relics`, re-apply with `Items.apply`, then
  `RelicFx.of(world).from_dict(saved)` (`to_dict()` holds tonic knowledge, fog, shield, cuckoo, brooch).
- **audio**: uses existing sounds only (`shoot`, `hit_wall`, `tick`, `bell_toll`, `charge`, `teleport`,
  `splash`, `explosion`, `item_get`, `bomb_place`). A dedicated flame-jet loop, glass chink, cuckoo call
  and music-box tune would help.

## Art
`python3 tools/art_items2.py --review <dir>` writes the 44 new icons (`assets/art/items/<id>.png`,
`ks_<id>.png`), helper sprites (`items/fam_*`), shot sprites (`items/fx/*`) and costume pieces
(`items/costume/*`), and contact sheets of all 69 icons together. It reuses the palette, grids and
outline pass of `tools/art_hero_fx_items.py`. All original; no new third-party assets.
