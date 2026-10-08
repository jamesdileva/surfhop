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
| endless | ~ inclines connected, SR3 at 50° (B1 withdrawn, B2/B3 ✅) |

Counts: **7 blockers reported, of which B1 withdrawn (no bug), B2+B3 fixed
this session;** 10 majors, 8 minors. Two `docs/history.md` claims fail
verification (§7).

---

## 1. Blockers (map element unusable, or data-loss class bug)

### B1. Endless generator/scene facing — CLAIM WITHDRAWN after verification ❌
Original claim: the shipped `.tscn` was baked by different code (negated
rotations), so regen would mirror the park. **Wrong.** `.tscn`
`Transform3D` serializes basis ROWS; hand-reading file triples as columns
transposes every normal, so all five "negations" pointed backwards. A
regen round-trip proved it: original literals reproduce the shipped scene
byte-identically (zero diff on SR1/SR2), and a sign flip by "standard-math
intuition" is what actually mirrored the park — caught by the endless
probe test, reverted same session. There was never any drift. Standing
rule (enforced by `_test_endless_repair` generator-vs-baked asserts):
trust the suite check, never file-eyeballed normals. The §9 regen warning
below is retracted; regen is safe and stable.

### B2. Endless platforms WERE unreachable — FIXED ✅
UpRampA (center y=88, half-length 725, sin16°) ends ≈ +307/−93 while
PlatformA top is 200 with ~200u of overlap band *under* the platform;
UpRampB ends ≈ +581/−53 with a 54u z-gap and ~390u wall to PlatformB top
340 (`generate_endless_map.gd:73-81`, `endless.tscn:120-157`). A 56u-apex
jump cannot board either end. **Fixed:** rebuilt as grade-meeting inclines
(UpRampA 8.5° floor→PlatformA top, UpRampB 7.2° PlatformA→PlatformB top,
walkable, no jumping), locked by `_test_endless_repair` reachability
asserts (low/high corner grade + footprint + walkable angle).

### B3. Endless SurfRamp3 sat exactly on the classification boundary — FIXED ✅
Baked slope was exactly 45.0° (angle reads the same transposed) with
strict-`<` classifiers (floor side) while glow-tagged surf by name.
**Fixed:** re-anchored to 50°, same facing family, asserted 49–51° in
`_test_endless_repair`.

### B4. Precision P3 ride-to-exit was impossible — FIXED ✅
P3 ended 46u short of Pool3 and 42u below it; entry buried. **Fixed:**
P3 re-angled 63°→60° (at 63° no exit can daylight over Pool3 — the line
crosses pool-top level past the pool edge), entries (0,−790,−2840), exits
(0,−1160,−3054) daylit 22u above Pool3 top. Difficulty now from placement
(void-gap entry, 150-wide face), not burial.

### B5. Precision P1/P2 exits were buried inside pool slabs — FIXED ✅
P1 exit face was 23u inside Pool1, P2 38u inside Pool2 — ride-to-bottom
clipped into solid. **Fixed:** both shortened along-line to daylight
(P1 exit 37u above Pool1 top, P2 ~15u above Pool2 top); riders launch off
the end and drop into the pool. Angles unchanged (55°/60°). Entries stay
demanding (controlled entry speed) — precision of entry IS this map's
skill. Locked by exit-daylight + honest-angle asserts and a live P1 ride
test (SURF, no slab clipping, ends in Pool1).

### B6. Stale respawn latch teleported fresh-map deaths to the old map — FIXED ✅
`GameManager._spawn_captured` latched the first player transform ever and
was never reset. **Fixed:** new `GameManager.reset_spawn()`, called from
`LevelLoader._finalize_load` on every map load — race-free (finalize +
emit + spawn positioning are atomic in one frame, so recapture always sees
the repositioned player). The suite's manual workaround line is removed;
`_test_spawn_latch_reset` covers reset-on-load, recapture, and
pre-checkpoint death landing on the new map.

### B7. `test_map` fixture shipped as playable — FIXED ✅
`MapSelect` listed every discovered map unfiltered (instant void fall on
select). **Fixed:** `HIDDEN_TAGS = ["dev", "test"]` filter in
`refresh_all()` — the loader still discovers fixtures, only the menu hides
them. Asserted in the main-menu flow test.

---

## 2. Majors (experts-only gates, broken flow, wrong guarantees)

### M1. Four mandatory flat void jumps needed 467–507 u/s — FIXED ✅
Intermediate A→B 350u, D→E 380u; Advanced B→C 380u, D→E 380u — all gated
experts at walk speed. **Fixed:** extended the floors toward each other so
all four gaps measure exactly 200u (needs ≤ 267 u/s — a fair walk-speed
bhop hop). Checkpoints, ramps, and kill planes untouched (same heights,
same positions otherwise). Locked by `_gap_between` asserts (real void >
0 and fair ≤ 200) in both map tests; existing void-raycast probes still
read mid-gap.
Intermediate A→B 350u → 467 u/s; D→E 380u → 507; Advanced B→C 380u →
507; D→E 380u → 507. Walk-speed riders fall to kill; difficulty 3 gates
experts. (Drop-jump bypasses at 320 all succeed, 491–707u ranges — the
punishment landed specifically on flat same-level gaps.)

### M2. Surf exits landed low with no high-line telegraphing — FIXED (with one correction) ✅
- Inter R1: **fixed** — FloorC extended 70u north so the face meets its
  top right at the edge (was: face hit landing level 48u over the void,
  riders fell short into the slab edge). Assert: exit past edge ≤ 60u and
  within 40u of top level.
- Adv R2→R2b: **fixed, in two attempts** — the M2 DOWN-step overlap
  looked right but trace evidence (M7 investigation) proved riders stalled
  in a pinch between the end caps; final form is a drop-transfer (R2b
  −65y, same 50° shape; 65° exit converges onto the shallower face).
  Assert: no UP step, plan overlap, live handoff.
- Inter R2 / R3, Adv R4: **re-derived during the fix and need NO change**
  — the audit treated "buried face end" as "exit fails", but the
  face-meets-slab-top transition happens 15–65u BEFORE the buried portion
  with 22u+ corner clearance (R2: transition −9515 vs burial −9535+;
  R3 touchdown −15107; R4 touchdown −19651). Ride-to-bottom dies, but
  natural riding transitions first. Lesson recorded: burial past the
  transition point is hidden and harmless.
- CS2 grounding (researched this session): linked segments overlap with
  top vertices almost touching; end-of-ramp discontinuities kill momentum
(rampbug literature); playerclip faces have zero cuts (ours are single
boxes ✓).

### M3. 65°/70° faces were thought to peel slow learners — CORRECTION: they retain ✅
Experiment (not theory) decided it: drop-in AND slow-slide riders retain
70° faces and accelerate (h=357/323 observed) — the 3 u/s/tick outward
push always loses to slide-buildup within ticks. The ">~65° peels" code
comment was wrong and is corrected in-file. Steep-face difficulty is
steering authority, not grip; the 48°→70° map curve is kept as the
intended progression and documented in the user guide (enter with speed
for control, never W into the ramp). Locked by `_test_steep_peel`
(drop-in + slow-slide retention on 70°, 50° control; solo worlds — a
shared world broke the control via edge-graze deflection).

### M4. Hold-to-bhop paid full friction every landing — FIXED ✅
Friction (module 0) ran before Jump (module 6) with the skip buffer armed
only on fresh presses: holders paid one full-friction tick (~19 u/s at
320) per landing. **Fixed:** BunnyHop samples `jump_held` every tick and
extends the same 0.1× skip to held-hop floor landings (surf-wall
touchdowns still excluded); the hop itself still fires next tick from
Jump. CS2 grounding: `sv_autobunnyhopping` exists precisely so hold
equals perfect presses — verified by negative control (without the fix:
320→301→283 across two landings, exactly the predicted bleed; with it:
parity). Locked by `_test_bhop_hold_parity` (95% single / 93% double,
W released to isolate friction); guide notes zero-penalty hold.

### M5. GROUND-beats-SURF braked lip carves — FIXED at the friction layer ✅
Verified all three sub-claims with weights: (a) 1-tick state lag is real
but 10ms-negligible — state machine untouched by design; (b) simultaneous
floor+wall classifies GROUND — real, but analysis showed friction is its
ONLY material gameplay effect (accel caps, jump/coyote, and HUD are all
already correct on real ground); (c) preservation off-by-one is real but
bounded (wall-slide preserves tangential velocity). **Fixed (b) only:**
`Friction` uses the surf rate when steep contact exists AND horizontal
speed exceeds walk speed (a carve, not standing); at/below walk speed
full friction still stops wall-leaners. No hysteresis state to mistune.
Locked by `_test_mixed_contact_friction` (carve keeps ~396/400, lean
stops, no-contact control bleeds); lip-riding integration covered by the
beginner channel traversal.

### M6. Surf steering had zero coverage — COVERED, no physics fix needed ✅
`AirMovement` runs before `Surf` and stays enabled in SURF, so W-into-ramp
is added then projected away each tick. Verified this is correct, not a
bug: the guide already teaches "never W into the ramp", and the new test
proves A/D + mouse redirects rides (> 15° carve vs hands-off drift, speed
kept) — the tangential residual is the whole steering mechanism, exactly
as CS doctrine expects. The optional wish-clip was dropped: no code change
could be justified against green evidence. Locked by `_test_surf_steering`
(+ `_ride_surf_face` helper with hands-off control).

### M7. Seam was ruler-measured, and the first fix was wrong — FIXED via drop-transfer ✅
The suite asserted `distance < 150u` and teleported onto each ramp solo.
First attempt (5u DOWN-step overlap, same session as M2) looked right on
paper — but the new live ride test (position/state trace) proved riders
stalled in a pinch between the segments' end caps: AIR state, frozen
h-speed, sliding underside faces, never touching R2b. Overlapping boxes
don't hand off; they trap.
**Fixed:** R2b translated −65y on the same 50.0° shape — a CS2
drop-transfer. The 65° exit trajectory converges onto the shallower face
below (a steeper path always meets a shallower face), and even
near-zero-speed riders drop straight onto it. Handoff proven: SURF ticks
past the seam, ≤1 cap-graze GROUND tick, momentum kept. (Boxed-segment
end caps stay walkable-angled by construction — one graze tick ≈ 24 u/s
per crossing is accepted; truly capless chains belong to M10.)
Locked by the seam-ride block (entry + cross + handoff + momentum) plus
the pre-existing ruler assert (now 70u, still < 150).

### M8. OC wall overhung the edge with unsigned entry — FIXED ✅
Face was at x=90 with the body center reaching x=257, 7u past FloorC's
±250 edge; nothing telegraphed the hop-to-surf entry. **Fixed:** face
pulled to x=80 (body max 247.4, inside bounds) plus a `SurfSign`
("hop onto the banked face and hold D") 250u before the wall, reusing the
tutorial-sign proximity pattern. Locked by face/overhang asserts, sign
presence/text/reveal asserts, and the updated live ride (drop follows the
face).

### M9. Beginner "unhoppable" channels are hoppable at speed
At 600 u/s (`R=750`) the whole 610u channel+gap clears longitudinally —
catch distance ∝ v² beats the 600u channels. Landing is safe (flush next
floor), but the design comment is wrong and speed-lines bypass the lesson.
**Remedy:** correct the comment; optionally raise walls for the R3
channel only.

### M10. Intermediate/Advanced relevance — M10a DONE, M10b DONE ✅✅, slice 2 (M10c reverted, R2 embeds) ✅, slice A (waterfall bridges) ✅
M10a shipped the new `rollercoaster` map (see above). M10b:
- **R2b exit daylight** (user-chose fix): shortened on the same 50° line
  to end 16u above FloorD top, 8u past its edge. Locked by daylight +
  angle asserts.
- **R4 entry** (was: 50u void coin-flip): FloorE extended 50u south and
  R4's top moved 25u down-face so its box end rests flush (R2-pattern 1u
  prow). Entry is a HOP from the slab (auto-bhop arcs clear the nub and
  land R4's upper face) — proven live with a deep ride. Cruise and
  walk-off entries were both disproven by trace: cruise sails over 70°
  faces (they fall away faster than gravity catches up); walk-offs wedge
  inside R4's box end. A standalone feed was tried twice and removed
  (47.7° flickered floor/steep into a friction stall; 53° wedged under
  R4's box end).
- **Bypass verdicts** (per-ramp ballistics): beginner channels and the
  R2+R2b void combo force commitment (SKILLED-ONLY/UNSKIPPABLE ✓);
  tutorial R1, inter R1–R3, adv R1/R4, precision pools, rollercoaster R3
  walk-around stay walk-bypassable — ACCEPTED, not fixable without
  breaking exit-meet geometry (proven twice: forcing distance
  contradicts landing distance). CS2 doctrine agrees: skilled flyovers
  are prehop expression; surf lines pay in exit speed (2–3×), which is
  what times sort on. New ramps follow the rule: exit-meet + daylight,
  time sorts the rest.
M10a shipped: new `rollercoaster` map (difficulty 3, tags surf/flow/air).
Start platform y=600 → 48.7° drop-in opener → Pool1 → 26.6° kicker launch
→ 55° transfer → drop-transfer to 60° → Pool3 + optional banked carve
wall → mini V-channel → 65° finale → catch-pool finish. Five pool
checkpoints, kill −2600, gravity untouched at 800 (airtime from speed +
geometry, per decision). Test lessons: steep faces need slow-drift drops
(60° out-descends fast entries); kicker starts must bury (exposed end
caps perch riders); kicker transfers are tuned for flow speed and tested
with input-driven bhop cruise, never velocity overwrites (which wedge).
Locked by discovery/angles/rides/chain-handoff/kicker-launch asserts;
smoke bot flows 2500u/8s (2× other maps).
Slice 2 forcing verdicts (M10c REVERTED — lips were jumpable: jump head
+128 from the slab clears any lip, and the 71.4° steepening broke R4's
prow-mount; back to M10b geometry):
- Tall prows tried and reverted: collinear face extensions are 150–200u
  walls across full-width corridors — walkers softlock (56-apex jump vs
  150u wall, 50°+ unwalkable, no way around), and speed flyovers still
  graze the corner and sail (trace: a steep face out-descends gravity, so
  a rider above it can never come back down onto it). Blocking flight is
  unphysical; CS2 doesn't either — forcing is routing, not walls.
- R2 cap-trap embeds (inter R2 51.6°, adv R2 62.7°, R4 pattern): the +10
  nubs' box-end caps (8% oversize + half-thickness rises ~32–35u above e1)
  trapped hop/cruise entries phase-dependently — diag showed the same
  spawn ±40u flipping mount/stall on hop-phase luck, riders pinned in
  SURF on the slab. Embeds bury the corners 20u+ under the slab tops;
  faces emerge at the slab edges; hop arcs meet open face. Suite proves
  all five faces (inter R1/R2/R3, adv R1/R2) mount from cruise-hop and
  ride deep, 581/581 green; both smokes OK.
- Residual: R1/R3/advR1 keep M10b +10 nubs with passing hop tests, but
  the same phase-fragility applies in principle — embed-all deferred
  (inter R1's 49–50.5° band conflicts with embed depth; needs band + doc
  changes, next slice). Test lesson: multi-entry ride tests must settle
  (drain stale SURF on flat slab after each teleport) or a stale state
  false-mounts instantly and the deep check fails at the slab.
Slice A waterfall verdicts (playtest: bhop lines sailed over detached
steep faces without touching them):
- Bridged 3: tutorial R1 flush start (same 48° — walkers meet a 30u nub
  not a 61u wall); inter R1 (flush at FloorB's edge, 50.2° daylight
  exit onto FloorC — band + ordering hold); adv R1 (1115u 50° run from
  an edge nub, diving under FloorB with a bridge transition at -6124).
  Flyovers land ON the face (drop-mounts); only elite speeds clear them
  whole (accepted mega-skips).
- Accepted with geometry proofs: inter R2/R3, adv R2 (bridging breaks
  angles, exits, or seams — gaps need 60°+ faces or buried exits that
  violate bands; skips need 400–650+); adv R4 (embedded, proven);
  precision P1–P3 (54–61° bands + daylight over-constrain any bridge;
  skips fall onto pools slower than surf-carry — self-penalizing via
  timer). Precision got FAST LINE signs instead (teach, don't force).
Standing M10b notes: 2500–5500u flat bhop slogs between drops remain on
inter/advanced BY DESIGN (flats are intentional bhop lines; M10a serves
flow) — vs CS2's exit-points-at-next-entry linking. Beginner passes
(flush alternation). M10b did not add chains, windows, or curves; those
stay future work per §6 tier levers.
Rollercoaster routing verdicts (playtest: lost past Pool3; P2 gap):
- R2 transfer restructured to transport (kicker flight lands Pool2 slab;
  mid-flight surf-meetings unmakable x13 rounds). FinishSign added at
  the channel mouth for Pool3→finale routing.
- Root cause: Pool2 (800 deep) buried R3's face (11u of 615u exposed) —
  R3 unmountable by construction. Pool2 800→450 (ends -2050); R3 face
  runs exposed into Pool3 (drop-mount past nub → deep ride → pool
  catch ~-2450). Suite 708/708; smoke 3070u/8s. ✅
- Doctrine: faces steeper than ~55° need near-vertical drop mounts
  (hop/run-off flights diverge — 60.5° face out-descends flights,
  gap grew 126→167u); land 20u past nub→face transition corners
  (corner contact perches).
Endless polish verdicts (playtest: white-on-white + wall-ramps):
- Sun ships (player rendered near-black under sky ambient); new
  "platform" role → mid-dark 0.55 (pure `dark_base_for_role()`),
  floor stays white, obstacles dark; 4 guide signs (spawn loop,
  E/W bank side-entry telegraphs, platform route). ✅
- Standing note: side banks (SR2 60°, SR3 50°) mount via side-entry
  along their 1600u length (frontal grade mounts diverge); spans
  proven to pierce grade (no stub walls). Test lesson: baked scenes
  instantiate off-tree — assert serialized `sign_text`, not labels.
Skypark retest verdicts (`ebae6b7`):
- White ramps root-caused: `WorldMaterials._surface_bodies` dead-code
  indent bug (append outside the `SurfRamp` guard) re-tinted every
  ramp white through the neon shader; AND skypark faces were never
  `SurfRamp*`-prefixed so the glow dark-base path skipped them. Both
  fixed (names renamed; guard now actually excludes). ✅
- Placement per slice-A doctrine: face tops buried inside approach
  slabs (T1FaceW -20u under T1, EastFace/VentCatch -8u under bowl,
  Drop -4u under summit) so hops land further down the SAME face;
  angles 55–56° → 53–54°; bottoms flush-merge at landing tops
  (T1FaceW → T2 top, EastFace/VentCatch → T1 top). Corners stay in
  the accepted ≤30u-nub family. ✅
- Standing note: summit/terraces carry the "platform" role (mid-dark);
  a floating face start (e1 above slab top) pokes ~48u lips through
  terraces — bury, don’t float.

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

### precision (45°, kill −1800, margin 600) — comments lied, since fixed ✅
| Ramp | Was (claimed/actual) | Now |
|---|---|---|
| P1 | "~63°" / 55.0°, exit buried 23u | 55.0°, exit daylights 37u above Pool1 |
| P2 | "~63°" / 60.0°, exit buried 38u | 60.0°, exit daylights ~15u above Pool2 |
| P3 | "~62°" / 63.0°, exit 46u short + 42u low | 60.0°, entry (0,−790,−2840), exit daylights 22u above Pool3 |
Widths stay 150u < CS 256 standard (expert by design, now telegraphed by
fair exits rather than burial).

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
| Endless SR3 "45°→48°, re-anchored" | **FAIL then FIXED** — true at audit time (generator `(0,0,−45)`, baked exactly 45°); repaired this session to 50°, same facing family, locked by test. |
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

1. ~~B3+B1+B2: endless repair~~ DONE — SR3 at 50°, inclines connected,
   facing lock green; B1 withdrawn (no drift — row/column misread).
2. ~~B4+B5: precision exits~~ DONE — exits daylight above pools, P3 at
   60°, live P1 ride test.
3. ~~B6/B7: respawn latch + MapSelect filter~~ DONE.
4. ~~M1: flat gaps~~ DONE — all four at exactly 200u, `_gap_between`
   asserts.
5. ~~M2: low exits~~ DONE — FloorC +70u, R2/R3/R4 verified fine;
   R2b finished under M7 as a drop-transfer (overlap attempt superseded).
6. ~~M3: steep curve~~ DONE — retention proven (no peel), comment +
   guide corrected, `_test_steep_peel`.
7. ~~M4: hold-bhop parity~~ DONE — same skip for held-hop landings,
   negative control 320→301→283, `_test_bhop_hold_parity`.
8. ~~M5: mixed-contact friction~~ DONE — surf-rate friction
   on fast steep contact (lips/seams keep carves); lag + preservation
   timing verified negligible/bounded, state machine untouched.
9. ~~M6: surf steering~~ DONE this session — carve proven (> 15° vs
   drift, speed kept), wish-clip dropped for lack of justification.
10. ~~M7: ridden seam test~~ DONE — overlap attempt trace-proven to
    pinch riders (AIR stall, frozen h-speed); rebuilt as drop-transfer
    (R2b −65y, same 50°), handoff + momentum + ≤1 cap-graze green;
    kill-check W-hygiene fix included.
11. ~~M8: OC wall + signage~~ DONE this session — face at x=80 in
    bounds, SurfSign telegraphs hop entry, asserts + live ride.
12. M10: rollercoaster rework — M10a DONE (new map), M10b DONE (R2b
    daylight, R4 prow entry, bypass verdicts), M10c REVERTED this session
    (blocker lips jumpable, R4 steepening broke its mount) and superseded
    by slice-2 forcing verdicts (§M10: tall prows reverted as unphysical +
    walker-softlocking, R2 cap-traps embedded R4-style, hop entries proven
    per face, R4 hop sign added).
13. Minors batch — DONE this session ✅
    - M9: channel "unhoppable" comments corrected (600+ clears accepted).
    - m1: floor_snap_length owned explicitly via MovementConfig (was
      unexamined Godot default).
    - m3: max_velocity documented as per-axis box clamp in-code.
    - m6: neon grid fwidth fade (distant moiré).
    - m7: OC obstacles + all channel lips embedded 2u (no more coplanar
      rest/z-fight).
    - m8: kill sweep reads spheres, ignores trigger volumes, skips
      dev/test fixtures (vacuous INF impossible), counts shipped maps.
    - Dead knobs removed: air_cap_multiplier, surf_speed_multiplier
      (zero code refs; docs/01 still lists them — flagged divergence).
    - m5-sequel: surf_entered with a raycast miss releases the glow
      instead of sticking to the previous wall.

## 9. Do-not warnings

- **Endless regen is safe** (B1 withdrawn — round-trip verified stable),
  but any future facing-sign change must go through the
  generator-vs-baked suite check, never file-eyeballed normals.
- **Resources are never hand-edited** (repo rule): all `.tscn`/`.tres`
  changes via generators + regen, as with every fix to date.
- Physics tick stays 100 Hz; `MovementConfig` stays the single home for
  tunables — no magic numbers in module math.
- The headless suite cannot see pixels (assignment-only material asserts
  + shutdown-noise ERROR waiver): every visual fix needs a human eyeball
  pass in a dev scene before close.
