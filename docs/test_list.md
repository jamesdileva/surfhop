# Playtest List — map-by-map polish pass

> Go one map at a time. Note failures as: map, spot (F1 coords),
> speed, what you did, what happened, what you expected.
> Launch: `godot --path . <scene>` (or `tools\godot.cmd` wrapper).
> Controls: WASD move, Space jump (hold = auto-bhop), mouse look,
> R restart-from-checkpoint, F1 debug overlay (speed/state/coords),
> Esc pause. S brakes while surfing. W into a ramp kills grip.

## 0. Cross-map checks (fix once, apply everywhere)

- [ ] Every `SURF RAMP` / `KICKER` / `CARVE` sign reveals on approach,
      hides on leave, and its advice works when followed literally.
- [ ] Hop entries: jump just before the ramp, rising arc meets open
      face, ride deep. No pinning in place while SURF on flat slab
      (that is the cap-trap stall — record map + ramp).
- [ ] Exits launch and land on the next surface (no void deaths on the
      intended line at cruise speed).
- [ ] Kill plane catches every miss; respawn is sane (near last
      checkpoint, moving).
- [ ] No white-on-white unreadables (face vs floor vs sky contrast).
- [ ] Smoke parity: if the bot flows it but you can't, that's a
      telegraphing bug, not a physics bug — note it.

## 1. Tutorial (`scenes/world/dev_tutorial.tscn`)

- [ ] School signs (Bhop/Strafe/Surf) reveal in order, advice works.
- [ ] SurfRamp hop entry mounts and rides to LowerFloor.
- [ ] Finish triggers results; timer/PB behave.

## 2. Beginner (`scenes/world/dev_beginner.tscn`)

- [ ] V-channel: drop in, carve wall-to-wall, exit with ≥ entry speed.
- [ ] Channel lips feel flush (embedded 2u — no edge chatter).
- [ ] 600+ u/s flyovers stay safe (accepted prehop expression).

## 3. Intermediate (`scenes/world/dev_intermediate.tscn`)

- [ ] R1/R2/R3 hop mounts from cruise + ride deep (signs guide each).
- [ ] Flat gaps (FloorA→B, FloorD→E) clear at walk-bhop pace.
- [ ] R1 exit meets FloorC (launch and land, no void).
- [ ] R3 drop from height produces SURF, no stall.
- [ ] Known residual: R1/R3 +10 nubs may stall unlucky hop phases
      (pinned SURF on slab) — record frequency; embed-all is deferred.

## 4. Advanced (`scenes/world/dev_advanced.tscn`)

- [ ] R1/R2 hop mounts + ride deep (signs guide each).
- [ ] R2→R2b drop-transfer: fall ~65u onto R2b, keep ≥85% momentum.
- [ ] R2b exit daylights onto FloorD (no slab clip at speed).
- [ ] R4 hop from FloorE + SignR4; ride past -19400.
- [ ] Void gaps are real (no cheap floors).
- [ ] Known residual: R1 +10 nub, same stall watch as inter R1/R3.

## 5. Rollercoaster (`scenes/world/dev_rollercoaster.tscn`)

- [ ] Flow: drop-in → pool → kicker launch → transfer → drop-chain →
      carve wall → channel → finale. No flat slogs, no full stops.
- [ ] Drop/Kicker/Wall signs match what the geometry asks for.
- [ ] Kicker transfers land the next ramp at flow speed (no wedge
      from velocity overwrites — bhop cruise only).

## 6. Endless (via main-menu map select)

- [ ] Park flows without dead ends; inclines ride both ways.
- [ ] Top-speed HUD + PB record/persist per session.
- [ ] Kill plane + respawn never strand the rider.

## 7. Challenge OC (`scenes/world/dev_challenge_oc.tscn`)

- [ ] SurfSign wall carve works (hop on, hold D, carve along).
- [ ] Movers/oscillators readable; obstacles embedded (no chatter).
- [ ] Jump puzzles fair at stated difficulty.

## 8. Challenge Precision (`scenes/world/dev_challenge_precision.tscn`)

- [ ] Pool drops onto P1/P2/P3 produce SURF at low + high speed.
- [ ] Exits daylight (no buried-face clips).
- [ ] Lines feel precise but possible — note any pixel-perfect asks.

## 9. Challenge Speedrun (`scenes/world/dev_challenge_speedrun.tscn`)

- [ ] Full route flows at speed; timer splits record.
- [ ] No unintended skips trivialize the route (note any).

## 10. Skypark — UNBUILT (seeds from `docs/open_maps_vision.md`)

Run these when S1–S4 land; structure mirrors §0–§9 above:

- [ ] S1 entities: booster sets the exact vector once per entry (no
      farming by sitting inside); vent lifts a 0-speed entrant out
      the top; neither fires on non-player bodies.
- [ ] S2 links (each at low + high entry speed): summit drop-in pays
      speed; kicker line lands every catch; booster gap is steerable
      (S-brake makes the catch); vent re-entry comfortable; no dead
      links; kill plane catches all misses; smoke ≥3000u.
- [ ] S3 wiring: top-speed PB records/persists/shows per map id; all
      KICKER/FLY/VENT signs reveal; menu boots arena with no timer.
- [ ] S4 feel: speed-cap verdict (does ~1000 u/s feel fast enough, or
      raise caps?); flights wide enough to airstrafe in (≥200u);
      catch ramps read at distance (contrast/glow).

## Reporting template

```
Map:
Spot (F1):
Speed:
Did:
Got:
Expected:
```
