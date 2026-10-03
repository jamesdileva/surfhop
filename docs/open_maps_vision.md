# Open Maps Vision — Phase 7: Skypark (new arena map)

> Status: vision + slice plan. Test-list and map-by-map polish follow.
> References: CS2 open surf (utopia-style fly sections, skyscraper
> verticality, nice_fly booster arenas, tower vents), `docs/idea.md`
> (Endless Movement: "huge skatepark, see how fast you can go"),
> `docs/02_Gameplay_Systems.md` (movement math), `audit.md` §M10.

## 1. Goal

One **new arena map** for fly-style surf: surf down → build speed →
launch (kicker, steep exit, or booster) → airstrafe the flight → catch
the next ramp → repeat, climbing back up a vent tower to loop. Scored on
**top speed** (endless precedent: `TopSpeed` + `SaveManager.record_top_speed`),
not time. Narrow corridor maps keep their checkpoint time-trial format;
Skypark is the playground.

Non-goals: touching rollercoaster/endless geometry (reuse only proven
patterns), multiplayer, trick scoring (idea.md long-term), map SDK.

## 2. Core loop and physics budget (gravity 800, fixed)

All launches are ballistics the engine already does. Worked examples so
catch ramps sit inside real trajectories, not wishes:

| Launch | Exit | Apex / airtime | Range |
|---|---|---|---|
| Kicker 25°, 600 u/s | vy ~250 | ~40u, ~0.6s | ~350u |
| Steep 60° exit, 700 u/s | vy ~600 | ~225u, ~1.5s | ~500u+ |
| Booster set 1200 u/s flat | vy 0 | drop only | 1000u+ glides |

Rules that fall out: catch ramps live **below and within ~300–800u** of a
launch; climbing needs boosters/vents (ballistics alone never gain
height); S-brake + airstrafe (already shipped) is the fly control, so
flights must be wide enough to steer in (corridor ≥ 200u).

## 3. Elements (reuse + two new game-layer entities)

Reuse as-is: surf drops (45–70°), kickers (`_ramp ascending`),
drop-transfers, carve walls, catch pools, SURF RAMP / KICKER signage
patterns, kill planes, top-speed scoring.

New (both live in `scripts/game/` or `scenes/props/` — game layer drives
the framework, never the reverse):

- **Booster**: Area3D that SETS `player.velocity` to a configured vector
  on entry (CS2 `trigger_push`). One-shot per entry (re-arm on exit) so
  riders can't farm it by sitting inside. Config: direction + speed,
  per-instance exports.
- **Vent tower**: cylinder zone applying upward accel while inside
  (the remembered tower that "pushed you back up"). Riders enter low,
  ride the column, exit high onto a ramp. Config: lift accel, radius,
  height. Kill-plane exempt inside the column; vent bases still sit
  above the kill plane (the tag registers a frame after entry, and the
  manager would win that race below it).

Both need live ride tests (enter → assert velocity/state trajectory),
same as every slice-2 ramp proof.

## 4. Map sketch (working title: Skypark)

Footprint ~4000×4000u, vertical budget ~1200u, all over one kill plane:

1. **Summit drop-in** (top, y≈600): wide 50° face — free entry speed.
2. **Fly bowl** (center, open airspace): descending surf chains left and
   right feeding a central kicker line.
3. **Kicker line**: 2–3 kickers (20–30°) aimed at catch ramps 300–600u
   out; each catch pays height or speed, player's choice of route.
4. **Vent tower** (middle): missed everything? Fall in the vent column,
   ride back to summit height, re-enter. The loop-closer.
5. **Booster gap**: one long booster-assisted flight (1200 u/s set)
   across the map to the far catch wall — the speed showcase.
6. **Catch chains**: linked faces with drop-transfers back down to the
   bowl. No finish line; top-speed HUD + PB.

Signage: KICKER / FLY / VENT telegraphs (rollercoaster precedent);
user_guide gains a fly-control section (S-brake, aim at the catch).

## 5. Slice plan

- **S1 — Booster + Vent entities**: `Booster.gd`, `VentTower.gd`
  (game layer), unit/live ride tests in a fixture map. Acceptance: set
  exact velocity once per entry; vent lifts a 0-speed entrant to its top
  exit; both ignore non-player bodies; suite green.
- **S2 — Skypark blockout**: generator function + map, all §4 zones at
  placeholder dressing, flow asserts per link (drop→face, kicker→catch,
  booster→wall, vent→summit), smoke flows ≥3000u. Acceptance: every link
  has a live ride proof; no dead links.
- **S3 — Scoring + wiring**: top-speed HUD/PB per map (extend endless
  pattern), menu entry, signs, guide section. Acceptance: PB persists
  per map id; signs reveal-tested; menu lists Skypark as arena.
- **S4 — Polish + test-list**: dressing pass, playtest-driven tuning
  (the map-by-map pass), speed-cap review (see §6).

## 6. Open questions / risks

- **Speed caps**: `max_velocity` is a per-axis box and `max_fall_speed`
  caps steep slides ≈1064 u/s (audit m3/m4). CS2 open maps run
  3500–10000. S4 decides: raise caps (config-only) or design inside
  ~1000 u/s. Booster set-speeds must respect whatever binds.
- **Arena respawn**: no checkpoints — kill plane returns rider to
  summit spawn (simplest) or last grounded (friendlier). S2 decides
  after blockout feel.
- **Performance**: big airspace, few bodies — expect trivial; profile
  in S4 per `docs/performance_profile.md`.
- **Menu flow**: arena mode (no timer/finish) vs time-trial UI — S3
  scopes the HUD/mode split.

## 7. Test-list seeds (expanded during the playtest pass)

- S1: booster sets exact vector once; vent lifts 0-speed entrant out
  the top; no farm, no misfire on non-players.
- S2: each zone link ridden live at low + high entry speed; smoke
  ≥3000u; no dead links; kill plane catches all misses.
- S3: top-speed PB records/persists/shows; all signs reveal; menu
  entry boots the arena with no timer.
- S4: cap decision playtested (does 1000 u/s feel fast enough?);
  vent re-entry comfortable; booster flight steerable (S-brake lands
  the catch).
