# Velocity Surf Audit — adversarial pass (2026-09-24)

> Method: three independent skeptical audits (ramp-geometry physics from
> generator endpoints + baked transforms, CS2 surf design research, code
> audit treating every history claim as unproven). Generator comments were
> found to lie in 3 places — all numbers below are recomputed from
> endpoints, baked `Transform3D` basis vectors, and box sizes, not comments.
> This file carries findings **plus** concrete remedies, ordered
> blockers-first per decision.

## Physics baseline (used for every calculation)

`walk_speed 320`, `jump_impulse 300`, `gravity 800` → rise 0.375s, flat
airtime 0.75s, apex 56.25u, flat range 240u at walk speed (`R(v) = v·0.75`;
with drop `D`: `T = 0.375 + sqrt(2·(56.25+D)/800)`, `R = v·T`). Surf =
wall contact with `normal·UP < cos(floor_max)`; `floor_max 45°` everywhere
except tutorial (`40°`, casual preset). No jumping from surf — riders must
ride to the exit (`scripts/movement/modules/Jump.gd:16-26`). `surf_friction
0.05`, `surf_preservation 0.95`, `surf_exit_boost 1.0` (~2 u/s placebo),
`surf_min_speed 20` / `surf_push 300` (slow riders peel off faces steeper
than ~68°). Tick 100 Hz. Scale 1u = 1 Quake unit.

## Executive summary

| Map | Rollercoaster verdict |
|---|---|
| tutorial | ✓ single clean ramp (reference element) |
| beginner | ✓ flush channel↔floor alternation (see M7) |
| intermediate | ✗ drop–slog–expert-gap, 2500u+ flat bhop slogs, exits land low |
| advanced | ✗ same disease + 65°/70° peelers, one pixel-perfect gap |
| precision | ✗ exits buried in slabs, P3 unrideable as built, faces < CS width |
| challenge_oc | ~ bhop/timing pure + one new optional surf wall (this audit) |
| challenge_speedrun | ✓ by design (no surf) |
| endless | ✗ park geometry disagrees with its generator; platforms decorative |

Counts: **7 blockers, 10 majors, 8 minors.** Two `docs/history.md`
claims fail verification (§7).

---

## 1. Blockers (map element unusable, or data-loss class bug)

### B1. Endless generator vs baked scene disagree on every ramp facing — regen mirrors the park
`tools/generate_endless_map.gd:63-68` emits rotations `(-50,0,0)`,
`(0,0,60)`, `(0,0,-45)`, `(-16,0,0)`, `(-28,0,0)`. The baked scene holds
the exact negations: SurfRamp1 basis y-column `(0,0.643,+0.766)` =
R_x(+50°) (`scenes/maps/endless.tscn:91`) vs generator R_x(−50°);
SurfRamp2 normal `(0.866,0.5,0)` = R_z(−60°) (`:101`) vs `+60°`; SurfRamp3
`(−0.707,0.707,0)` = R_z(+45°) (`:111`) vs `−45°`; same negation on
UpRampA (`:131`, +16° vs −16°) and UpRampB (`:152`, +28° vs −28°).
The shipped `.tscn` was baked by different code than today's generator.
**Remedy:** decide the canonical facing (baked = playtested), flip the
five generator signs to match, add a test comparing generator output
transforms to the baked scene. **Do NOT run the endless regen until this
is fixed** (see §9).

### B2. Endless platforms are unreachable in both sign conventions
UpRampA (center y=88, half-length 725, sin16°) ends ≈ +307/−93 while
PlatformA top is 200 with ~200u of overlap band *under* the platform;
UpRampB ends ≈ +581/−53 with a 54u z-gap and ~390u wall to PlatformB top
340 (`generate_endless_map.gd:73-81`, `endless.tscn:120-157`). A 56u-apex
jump cannot board either end. **Remedy:** rebuild approaches as reachable
inclines (rise ≤ ~50u per jump, overlapping landings) or cut the
platforms; add a reachability test (simulated jump between endpoints).

### B3. Endless SurfRamp3 sits exactly on the classification boundary
Baked normal `(−0.707,0.707,0)` ⇒ slope exactly 45.0°
(`endless.tscn:111`); both classifiers use strict `<`
(`Collision.gd:37`, `Surf.gd:33`), and the engine's `floor_max_angle`
calls it floor — while `VisualEffects` tags it surf-glow by name prefix.
Expect walk/stick flicker. This is the same bug class history claims was
fixed twice (tutorial got its 48°; endless never did — §7). **Remedy:**
re-anchor to 50° (rotation + normal + test).

### B4. Precision P3 ride-to-exit is impossible as built
P3 (`(0,−800,−2800)→(0,−1220,−3014)`, actual 63.0°, 150 wide) ends 46u
SHORT of Pool3 and 42u BELOW it with downward velocity; its entry face is
buried 32u below Pool2's top (≈150u below the rider's feet at the pool
edge). **Remedy:** extend the ramp 60u, raise the exit 45u, unbury the
entry; or downgrade P3 to an aerial-transfer bonus with telegraphing.

### B5. Precision P1/P2 exits are buried inside pool slabs
P1 exit face 23u inside Pool1 (44u inside footprint); P2 face 38u inside
Pool2. Ride-to-bottom clips into solid; only early side-exit aerials work.
**Remedy:** shorten pools or extend ramps so exits daylight ≥ 20u past
slab edges; assert daylight in tests.

### B6. Stale respawn latch teleports fresh-map deaths to the old map
`GameManager._spawn_captured` latches the first player transform ever and
is never reset (`GameManager.gd:24,37-39`); `LevelLoader._finalize_load`
resets race/checkpoint/kill state but not the latch (`:85-104`). Map A →
checkpoint → quit → map B → die before any checkpoint ⇒ respawn at map-A
coordinates, likely mid-void ⇒ death loop. The suite works around it
(`test_runner.gd:1185`, *"autoload state leaks between suites; recapture"*)
instead of fixing it. **Remedy:** reset the latch in `_finalize_load`
(or on `Game.start_map`); convert the test workaround into a regression
test (die on fresh map ⇒ respawn inside new map bounds).

### B7. `test_map` fixture ships as playable (instant void fall)
`MapSelect` lists every `discover_maps()` entry unfiltered
(`MapSelect.gd:72-73,81-91`); `test_map.tscn` has a Floor with no
collision/mesh and a `PlayerSpawn` marker nobody reads (`Game`/`DevMain`
want `RespawnPoint`, fall back to `(0,60,0)` over void). **Remedy:**
filter `dev`/`test` tags out of MapSelect (decision: hide it).

---

## 2. Majors (experts-only gates, broken flow, wrong guarantees)

### M1. Four mandatory flat void jumps need 467–507 u/s (47–58% over walk)
Intermediate A→B 350u → 467 u/s; D→E 380u → 507; Advanced B→C 380u →
507; D→E 380u → 507. Walk-speed riders fall to kill; difficulty 3 gates
experts. (Drop-jump bypasses at 320 all succeed, 491–707u ranges — the
punishment lands specifically on flat same-level gaps.) **Remedy:** shrink
to ≤ 240u, add ramp bridges, or move them behind explicit skill gates.

### M2. Surf exits land low with no high-line telegraphing
Intermediate R1/R2 (−10u vs landing, face −18/−19u), Advanced R2→R2b
(13u gap + 10u UP step against vy≈−700), all demand CS high-line
technique (exit 200u+ high with 400+ horizontal) that nothing teaches;
ride-to-bottom = wall/fall. Only Advanced R1 is perfect (entry +1, exit
−1, bridges 370u). **Remedy:** daylight exits ≥ landing level, or add
tutorial signage for the high line; assert exit-face ≥ landing−2u.

### M3. 65°/70° faces peel slow learners; R4 is an elevator shaft
Advanced R2 (65°) / R4 (70°): `anti_stuck` peels riders under ~20 u/s
horizontal (`Surf.gd:101-106`, crossover ≈ 68°). Cannot be learned slowly;
must enter hot. **Remedy:** keep for advanced but gate progression
(50°→60°→65°→70° across maps already exists — document it as the
intended curve) and assert peel/retain behavior (§8.4).

### M4. Hold-to-bhop pays full friction every landing (two-tier bhop)
`Friction` runs at module index 0, `Jump` at 6
(`MovementController.gd:8-18`); the skipping buffer arms only on
`jump_just_pressed` (`BunnyHop.gd:18-21`). Press-technique keeps ~98%,
hold-technique (the advertised default: `auto_bhop=true`, smoke path)
loses ~19 u/s per landing ≈ 94%, below the suite's own 95% bar — which
only exercises the press path. **Remedy:** arm the skip on grounded
hold-jump landings too, or document the tiers; add the parity test (§8.5).

### M5. One-tick state lag + GROUND beats SURF at every lip/seam
`_resolve_state()` reads last tick's contacts (`MovementController.gd:86,
132-137`); `on_floor()` is checked before steep, so simultaneous
floor+wall contact (lips, channel junctions, slab creases) classifies
GROUND → friction 6.0, and a buffered press auto-ejects at the lip via
`BunnyHop.on_land:31` — contradicting the "surf touchdowns never eject"
guarantee (whose test only covers pure-wall touchdowns). The A2 entry
preservation also compensates one tick late (engine clipped during the
AIR-state contact tick). **Remedy:** prefer SURF on mixed contact when a
steep normal exists; move preservation to cover the contact tick; extend
the no-eject test to lip (floor+wall) touchdowns.

### M6. W-into-ramp energy is added then deleted every tick
`AirMovement` runs before `Surf` and is enabled in SURF
(`AirMovement.gd:10-14`); `process_surf` then projects the normal
component away. Only tangential A/D + mouse steering survives — correct
per CS doctrine (never W on ramps) but zero suite coverage applies any
input during SURF (all rides are no-input slides). **Remedy:** add the
steering test (§8.1); optionally clip wish to the plane pre-accel.

### M7. Seam chains asserted by ruler, never ridden
`steep_normal()` keeps only the FIRST steep contact (`Collision.gd:32-39`)
— at the R2(65°)→R2b(50°) seam both planes touch and the second is
discarded. The suite asserts `distance < 150u` and teleports onto each
ramp solo. **Remedy:** ride-across-seam test with zero GROUND ticks (§8.3).

### M8. OC SurfRampB1 needs a hop to surf; body overhangs the edge
Grounded contact classifies GROUND, so walk-in riders grind instead of
surfing — must hop (56u apex reaches the lower third, face x≈128 at apex)
then carve. "Veer and press D" omits the hop. Body center x=173.7 extends
to 257, 7u past FloorC's ±250 edge. **Remedy:** document the hop entry
(surf sign), pull face to x=80.

### M9. Beginner "unhoppable" channels are hoppable at speed
At 600 u/s (`R=750`) the whole 610u channel+gap clears longitudinally —
catch distance ∝ v² beats the 600u channels. Landing is safe (flush next
floor), but the design comment is wrong and speed-lines bypass the lesson.
**Remedy:** correct the comment; optionally raise walls for the R3
channel only.

### M10. Intermediate/Advanced are not rollercoasters
2500–5500u flat bhop slogs between drops plus stop-on-fail voids, vs
CS2's exit-points-at-next-entry linking with no flat transit. Beginner
passes (flush alternation). **Remedy:** backlog item — interleave ramps
(drop→ramp→drop), convert the M1 flats to surf bridges, add variety
(curves, trapezoid faces, windows) per §6 tier levers.

---

## 3. Minors

- **m1.** `floor_snap_length` never set (Godot 0.1u default unexamined vs
  lip-catch behavior). Own it or leave it — currently nobody does.
- **m2.** Exact-equality fragility: `cos()` recomputed in three places vs
  engine epsilon; suite probes 44°/46° on default only, never the casual
  40° band (41–44° surfs tutorial, walks elsewhere).
- **m3.** `max_velocity (4000,1500,4000)` is a per-axis box (≈5656 diagonal),
  not a speed clamp; vertical leg never binds before `max_fall_speed`.
- **m4.** `max_fall_speed` clamps before Surf projects, capping 70° slides
  ≈1064 u/s total. Never reached in practice (~660 observed); note for
  future long/steep maps.
- **m5.** Surf-glow raycast can stick to the previous ramp across rapid
  ramp-to-ramp switches (ray hits non-ramp body at seams → null → old glow
  decays in place).
- **m6.** Neon grid has no `fwidth` fade (distant moiré) and fresnel→0
  overhead leaves far field flat. Headless suite asserts assignment only.
- **m7.** OC pillars/LowWall/movers rest coplanar on floor tops (bottom =
  0 = floor top) instead of embedding 1–2u. Stable; one physics version
  away from edge chatter.
- **m8.** Kill sweep blind spots: BoxShape-only, trigger volumes counted
  as surfaces, `test_map` passes vacuously (INF), mover runtime amplitude
  ignored. Fix with the B7 test_map work.

---

## 4. Per-map ramp tables (recomputed, comments distrusted)

Physics shorthand: flat range @320 = 240u; drop-jump ranges computed per
§0 baseline. `_ramp()` faces sit ~7–22u below endpoint lines (steeper =
deeper); "buried" verdicts hold on raw endpoints.

### tutorial (`floor_max 40°`, kill −1000, margin 586)
| Ramp | Angle | Slope/box, width | Entry | Exit |
|---|---|---|---|---|
| SurfRamp | 48.0° (436/393) ✓ | 587 (634) / 400 | prow ~24u proud of CourseFloor, bump on mount | flush into LowerFloor, 72u inside. PASS |

### beginner (45°, kill −960, margin 199 — tightest, abrupt but fine)
56.0° faces (+11°), 600u rides, lip 120×600. Entries 10–110u gaps with
250u drops: catchable @320 run (253u) and jump (400u); @600 overshoot
lands safe on flush next floors. All exits flush (0–50u overlap). Mouth
funnel ±229u at takeoff height from 800-wide floors.

### intermediate (45°, kill −2600, margin 800)
| Ramp | Angle | Len/box, width |
|---|---|---|
| R1 | 50.0° (500/420) | 653 (705) / 340 |
| R2 | 55.0° (550/385) | 671 (725) / 340 |
| R3 | 60.0° (800/462) | 924 (998) / 340 |
Entries flush/overlap at any speed. Exits all land low (R1 −10u/face
−19u; R2 −10u/−18u; R3 ±0/−8u mildest). Mandatory flats A→B 350u (467
u/s), D→E 380u (507 u/s). Drop-jump bypasses @320 succeed (491–585u).

### advanced (45°, kill −4600, margin 1610)
| Ramp | Angle | Len/box, width |
|---|---|---|
| R1 | 59.9° (800/465) | 925 (999) / 360 — the only perfect ramp in the repo |
| R2 | 65.0° (700/327) | 773 (834) / 360 — peel zone |
| R2b | 50.0° (600/503) | 783 (846) / 360 |
| R4 | 70.0° (900/328) | 958 (1035) / 360 — elevator shaft |
R2→R2b: 13u gap + 10u UP step, must transfer high. R4 entry 50u past
FloorE edge, exact @320 stick, forgiving above. C→D 700u/1290drop barely
jumpable @320 (7u margin — pixel-perfect; easy @500). Flats B→C, D→E
380u → 507 u/s.

### precision (45°, kill −1800, margin 600) — comments lie
| Ramp | Claimed | Actual | Len/box, width |
|---|---|---|---|
| P1 | ~63° | 55.0° (420/294) ❌ | 513 (554) / 150 |
| P2 | ~63° | 60.0° (420/242) | 485 (524) / 150 |
| P3 | ~62° | 63.0° (420/214) | 471 (509) / 150 |
Widths 150u < CS 256 standard (expert by design, keep + telegraph).
Bypassable by jumps @320 (200u/400drop → 462u), so surfs read optional.

### challenge_oc (45°, kill −950, margin 950)
SurfRampB1: 56° face (+11°), 500(Z)×240 slope, face x=90, z −4550..−5050;
hop-to-enter; finish −5450 (400u past wall, 150u from map end). LowWall
top 44 < 56.25 apex, 112–210u window @320–600 ✓. Movers timing-only
(240u gaps on phase, 4/5s periods).

### endless (45°, kill −2000, margin 2000) / speedrun (flat, by design)
SR1 50° huge ✓; SR2 60° ✓; SR3 45.000° BLOCKER (B3); UpA/UpB 16°/28°
walkable ✓; corridor verticals accidentally surfable (fun, keep).

---

## 5. CS2 surf reference (researched Sep 2026)

Benchmarks: `surf_beginner` (Kiiru, T1 staged 7), `surf_utopia_njv`
(Panzer, T1 linear), `surf_mesa` series + `mesa_aether` (Arblarg, T1–T3
linear 6 checkpoints — the flow reference), `surf_kitsune` (Arblarg, T1
staged 9, the rollercoaster reference), `surf_ace` (T2 staged 8+bonus),
`surf_rookie` (T2 staged 18).
**Rules:** surf threshold >45° (Source standable limit 45.573° — our 45°
is heritage-correct); bands 45–50 gentle / 50–60 fast / 60–80 expert
(matches our docs §4.7); editor default slant 5:4 = 51.3° (sane T1/T2
default); T1 faces 256–512u+ wide, 512–1024u+ long (at 2000 u/s a 600u
ramp is a 0.3s ride — prefer 700–1000u); maxvel 3500 standard, 7200 fun
(ours 4000 + margin ✓); gravity 800, jump ≈50u, tick 64/100/128 (ours 100
✓); NEVER W on ramps (A/D + mouse only; S = brake); flat gaps >~250u
require bhop speed and kill T1 flow; exit velocity must already point at
the next entry (overlaps, 10u step-downs, gentle curves — no flat
transit); staged maps give per-stage timers + teleports (`!r/!stage),
linear maps split-compare; fail-safety = teleport-back, not death.
Difficulty levers: narrower/steeper/shorter-catch, spins, windows,
pillars, ramp-strafes, headchecks, speedchecks, maxvel limits.
Sources: `github.com/Chent-AU/CS2-Surf-Mapping` (ramp types, >45° rule,
anti-rampbug clips); Steam guides 144073931 (BReeZ tiers/technique),
961251261 (physics presets); `developer.valvesoftware.com/wiki/Dimensions`
(45.573°, 33u clearance); `critfeed.com/cs2-surf-commands` (presets);
workshop pages for beginner/kitsune/mesa_aether/ace (tiers, maxvel).

---

## 6. History cross-check (claims vs code)

| Claim | Verdict |
|---|---|
| Channel walls "350→500 tall for longer carves" | **FAIL** — boxes are `(40,400,length)` (`generate_maps.gd:98,104`), half-extent `slope=200` (`:86`). 400 ≠ 500 (≠ 350). |
| LowWall 80→44, top < apex | HOLDS — `(500,44,40)` at y=22 (`:441`); suite asserts top ≤ 50. |
| casual.tres 42→40 to match floor | HOLDS — both exactly 40.0; contract tests green. |
| Endless SR3 "45°→48°, re-anchored" | **FAIL** — generator still `(0,0,−45)` (`generate_endless_map.gd:68`); baked still exactly 45° (`endless.tscn:111`). Tutorial got its 48°; endless didn't. |
| air_accel 14 cap-limited by cap 45 | HOLDS — first-tick add `14·0.01·320 = 44.8` vs `45 − current` (`AirMovement.gd:34-36`). |
| Exit boost ~2 u/s placebo, flagged | HOLDS (honest) — math confirms ~1.5–1.8 u/s. |
| Beginner kill-plane "−1600 kept" | SUPERSEDED — round-3 channels replaced that geometry; current −960 matches shipped design. Stale, not a lie. |

Also verified holding up: no friction double-application (GROUND-only +
consume-once override); no remaining instance/global uniform mismatch
(both shaders instance-clean where per-instance writes occur);
no WHITE tint fallback (palette-or-explicit always); movers included in
styling + tagged obstacle; channel bank math correct (56° normals toward
center); tutorial angle, LowWall, casual thresholds, OC bank all green in
suite.

---

## 7. Test-coverage holes (concrete assertable checks, unimplemented)

1. **Steering while surfing** — 50° ramp ride + `move_right` + yaw
   +0.03/tick × 60: heading change > 15°, no speed collapse vs no-input
   control. (Zero input applied during any SURF ride today.)
2. **Boundary + preset band** — 44.9° ground / 45.1° surf agreement across
   all three classifiers; casual 41° SURF under casual, GROUND under
   default. (Today: 44°/46° default only.)
3. **Seam ride** — downhill velocity at the R2→R2b seam: SURF persists
   across z ≈ −12990 with zero GROUND ticks; lip entries ≤ 2 GROUND ticks.
   (Today: ruler-only.)
4. **Peel vs retain** — 70° ramp at h=10 separates within 60 ticks; 50°
   ramp at h=10 retains 120 ticks. (Anti-stuck entirely unasserted.)
5. **Bhop parity + sweep honesty** — 320 u/s landing with jump HELD retains
   ≥ 95% (expected to fail ≈94% per M4 — that IS the test); `test_map`
   Floor owns ≥ 1 BoxShape (kills the vacuous INF pass); Sphere-only low
   surface documents non-Box exclusion.

---

## 8. Fix backlog (blockers-first order, per decision)

1. B3+B1+B2: endless repair — re-anchor SR3 to 50°, flip generator signs
   to baked-canonical, reconnect platforms reachably, add
   generator-vs-baked + reachability tests. Then regen endless ONLY.
2. B4+B5: precision exits — extend/unbury P1–P3, daylight asserts.
   Correct the three angle comments.
3. B6: respawn latch reset on map load + regression test (replacing the
   suite workaround).
4. B7: MapSelect tag filter (hide `dev`/`test`).
5. M1: hold-bhop friction parity (or documented tiers) + test.
6. M2+M5: mixed-contact prefers SURF; preservation covers contact tick;
   lip no-eject test.
7. M8: OC wall face x=80 + surf signage (hop entry).
8. M2-exits/M10: exit daylighting pass; rollercoaster rework of
   intermediate/advanced (separate sprint — biggest item here).
9. M9/m7/m1: comment correction, coplanar embedding, snap ownership.
10. M6/m3/m4/m5/m6/m8: dead knobs (wire or remove), clamp docs, glow
    seam behavior, grid fade, sweep blind spots.

## 9. Do-not warnings

- **Do NOT re-run the endless-map generator** until B1 signs are fixed —
  it will mirror all five slabs (verified facing math above).
- **Resources are never hand-edited** (repo rule): all `.tscn`/`.tres`
  changes via generators + regen, as with every fix to date.
- Physics tick stays 100 Hz; `MovementConfig` stays the single home for
  tunables — no magic numbers in module math.
- The headless suite cannot see pixels (assignment-only material asserts
  + shutdown-noise ERROR waiver): every visual fix needs a human eyeball
  pass in a dev scene before close.
