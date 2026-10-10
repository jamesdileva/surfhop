# Worklog — quality audit + rollercoaster flow restore (2026-10-02)

## Audit of last commits (per user request)
- 6efbf9c (M10c lips): verified baked scenes match source (advanced
  e1 metas 85/-715/-2114 == generator). Consistent, good.
- 442bce0 (guide): docs-only. No risk.
- Uncommitted work: needed its regen (stale Kicker1 scene would have
  broken the renamed meta lookups); fixed a garbled shader comment.

## Shipped (c75cc77)
- Rollercoaster R2/R4 reverted to M10a anchors (raised prows blocked
  mounts: R2 145u over Pool1, R4 85u over Floor4).
- Kicker1 -> SurfRampKicker1 (dark-base + glow; was invisible white).
- Test bands/drops re-anchored to restored geometry.

## Verify
- Suite 567/0; rollercoaster smoke 2500u/8s (was 83u blocked).

Next: resume M10d scoping (kicker variants, wall curve tops) or
playtest verdict on lips elsewhere.

# Worklog — slice 2 forcing verdicts: M10c reverted, R2 embeds (2026-10-03)

## What slice 2 settled (audit M10)
- M10c blocker lips (+75 e1) REVERTED to M10b geometry (tutorial, inter,
  adv, precision): jump head +128 clears any lip, and the steepening broke
  R4's prow-mount. Regen + churn-revert; tutorial/precision diffs are the
  revert itself.
- Tall prows tried and REVERTED (collinear extensions, same angles): trace
  proved speed flyovers graze the corner and sail (steep face out-descends
  gravity — a rider above it never comes back down), and 150-200u walls
  across full-width corridors softlock walkers. Forcing is routing, not
  walls. All 5 prow-contact tests failed the same way — correct call to
  delete, not tune.
- R2 cap-traps EMBEDDED R4-style: inter R2 e1 -470 -> -535 (51.6 deg,
  R1<R2<R3 holds), adv R2 e1 -790 -> -856 (62.7 deg, band holds). The +10
  nubs' box-end caps (8% oversize + half-thickness rise ~32-35u above e1)
  trapped entries phase-dependently (diag: same spawn +/-40u flips
  mount/stall on hop-phase luck). Corners now 20u+ under slab tops.
- R4 hop-entry sign added (SignR4 on FloorE, reveal-tested).
- Tests: hop-mount + ride-deep per face (R4 pattern), SignR4
  present/worded/reveal. Suite 581/581; smokes intermediate + advanced OK.

## Lessons (load-bearing)
- Multi-entry ride tests MUST settle stale SURF after each teleport:
  identical slab-rest failure coords across geometry changes was the tell
  (stall precedes any ramp contact). Drain on flat slab before mounting.
- Diag scripts run under GM-autoload kill default -1000 (not the map's
  -2600): a mid-face "teleport" was a legit kill-respawn to last ground.
- NEVER write files via PowerShell (Set-Content rewrote test_runner.gd
  as ANSI -> invalid-UTF-8 parse failure). Edit tool only; recovered via
  cp1252->UTF-8 round-trip, zero loss.
- `_ramp` box = 8% oversize + sunk 14u: embed math must clear corner rise
  (margin*sin + 20*cos above e1), not just e1.

Next: embed-all deferred (R1 49-50.5 band vs embed depth; needs band+doc
changes); R4-sign pattern for other hop faces; playtest verdict on feel.

# Worklog — slice 3 hop-entry telegraphs (2026-10-03)

- Same-issue-across-maps fix: hop-mount is suite-proven but
  undiscoverable (riders cruise into nubs and stall). SignR4 pattern
  extended: inter SignR1/R2/R3, adv SignR1/R2 — right side, 40u above
  slab, ~180u before each prow. Uniform text ("SURF RAMP / Hop onto the
  face / and ride it down!").
- Tests: per-map sign loops (present + TutorialSign + hidden + text +
  reveal). user_guide §3 gained the hop-entry doctrine (2 lines).
- Rollercoaster already telegraphed (Drop/Kicker/Wall signs, M10a);
  tutorial has its school signs; precision pool-drops are a different
  technique (out of scope).
- Verify: suite 601/601 (+20 sign checks); smokes inter/adv OK.

Next: test-list for user playtest (one map at a time); then vision
doc/plan/scope for open surf-kicker-catch maps (rollercoaster/endless).

# Worklog — Skypark S1 entities: Booster + VentTower (2026-10-03)

- `scripts/game/Booster.gd` (class_name): CS2 trigger_push, sets exact
  velocity once per entry, re-arms on exit, ignores non-players,
  self-builds a default sphere. `scripts/game/VentTower.gd`: lift accel
  clamped to max_rise_speed, self-builds cylinder, manages `in_vent`
  group (enter/exit signals + physics ensure for teleport-in races).
- GameManager kill branch honors `in_vent` (one-line game-layer check).
- Tests `_test_skypark_entities` (fixture world, no map): exact set,
  once-per-entry, re-arm, non-player ignore, 0-speed lift-out,
  tag/untag, kill exemption. Suite 610/610 (+9).
- Load-bearing: kill-test ordering (teleport before raising kill, or
  GM wins frame 1); new class_names need `--editor --quit` before the
  headless suite sees them.
- Vision doc: vent bases sit above kill (design rule).

Next: S2 Skypark blockout (generator + map + per-link ride proofs).

# Worklog — Skypark S2 blockout: all links green (2026-10-03)

- Map: summit drop-in (embedded 47.6°) -> bowl -> west kicker -> T1 ->
  T1FaceW (edge-emerge 56.9°, T2 meet) -> T2 traverse -> T3 step (50
  down, adjacent) -> runout; east edge-drop face (58°, T1 merge);
  booster lane -> T2; vent tower + VentHop transit -> bowl; VentCatch
  edge-drop -> T1 merge. Kill -1600, summit respawn, no
  checkpoints/timer (arena). 8 signs. Smoke 3218u/8s.
- Tests: 50 skypark checks (L1-L8 links, signs) — suite 661/661.
- DOCTRINE (paid for in ~9 regen rounds, trace-proven): flights
  TRANSPORT (land flat, huge targets), surfing resumes via hop-mount /
  edge-drop / drop-mount faces. Mid-flight surf-catches of floaty arcs
  are unmakable: the 8%-oversize box corner poisons ±40u around every
  top edge (below grazes/pins, above sails), and steep faces
  out-descend falling flights. Nub faces need edges (steep faces bury
  within ~7u on flat); faces can't run along slab tops (bury);
  T2->T3 grade too small for faces (runout instead).
- Load-bearing: open-air hover-pins are corner-graze depen sticks (ray
  -cast the box ends, don't theorize); empty-world fall is clean
  (gravity fine); `<` vs `<=` on exact-set booster vectors (epsilon
  miss); no-jump cruises friction-stop into cliff seams (bhop over);
  weak ground friction lets sliders run past zones (assert touchdowns
  and falls, not rests); teleport+zero+fresh-player per link beats all
  stale-state ghosts; vent bases above kill (GM wins frame 1 below).

Next: S3 scoring + wiring (top-speed HUD/PB, menu entry, guide fly
section); S4 polish + cap review; then the map-by-map playtest pass.

# Worklog — Skypark S3 scoring + wiring (2026-10-03)

- You were right: top-speed HUD/PB existed (E1 endless), gated on the
  "endless" tag. Generalized the gate to endless/arena in TopSpeed +
  HUDController (no core change); skypark menu entry was already
  automatic (discover, non-hidden tags). Missing pieces were the gate,
  tests, and the guide's fly-control section (S-brake never documented).
- Tests: `_test_skypark_scoring` (tracker gate, per-map-id persist,
  announce, arena HUD layout) + skypark menu-row assert. 675/675 (+14).
- Guide: "Flying the gap" (S-brake, aim at catch, booster commit).

Next: S4 polish + cap review; then the map-by-map playtest pass.

# Worklog — OC finale: kicker up + surf across (2026-10-03)

- Playtest: banked wall sat on the finish platform (random), course
  felt unfinished. New finale: kicker UP off FloorC, fly to entry
  pool / finish slab (transport, flat landings), hop-mount surf face
  ACROSS the void, drop-link onto a dedicated finish slab with its own
  checkpoint. Kill -950 -> -1200 (sweep margin under the slab).
- Tests: launch + long landing + mount + deep + slab landing + both
  signs; checkpoints 2->3. Suite 701/701; OC smoke OK.
- Doctrine holds again: kicker->face mid-flight meetings unmakable
  (same corner/sail physics as S2); flights land flat, surfing resumes
  via mounts. resources/maps/*.tres are dead files (nothing reads
  them); baked map_metadata rules.

# Worklog — Slice A waterfall entries (2026-10-03)

Shipped: tutorial R1 flush start (same 48°), inter R1 bridged (flush
at FloorB edge, 50.2° daylight exit), adv R1 long-bridged (edge nub,
50° run diving under FloorB with bridge transition), precision speed
signs (FAST LINE — geometry can't force inside angle bands + daylight,
so teach; skips self-penalize via timer). Suite 688/0; 4 smokes OK.
Accepted with reasons (documented in audit): inter R2/R3, adv R2/R4
(gaps can't bridge without breaking angles/exits/seams; skips need
400-650+, skill-gated, timer sorts), precision geometry (bands +
daylight over-constrain any bridge).

Test lessons (load-bearing, several paid for twice):
- Unguarded get_node in a loop ABORTS the func on first miss (speedrun
  skipped + cleanup skipped + leaked players poisoned GM for roller/
  L8/menu). Guard with get_node_or_null + null-continue, always.
- A dedented _check runs for EVERY loop map (phantom P1 fails on OC +
  speedrun). Watch block levels after edits.
- Drop-point calibrations must follow geometry moves (recompute
  surface, respawn 10-20u above it).
- Spawns that fall inside nub footprints bonk-bounce north (depen
  eject); spawn clear, hop over — or drop-mount (phase-free).
- Match map_id (not just non-null) on async loads; fail fast on stale.
- `<` vs `<=` on exact-set booster vectors (epsilon miss).
- Capture full suite output to a file; tail/First-N truncation plus
  stdout/stderr interleave manufactures mysteries (cut CHDBG lines,
  split error records).
- Bit-exact repeats = deterministic (diag vs suite divergence means
  context differs: input phase, load timing — fix with phase-free
  tests (drops, fresh players), not more theory.

# Playtest round 1 verdict + scope (2026-10-03)

User verdict: waterfall faces bhop-overable on tutorial/intermediate/
advanced/precision R1s (face sits detached in the gap; jump clears it
start-to-finish). Beginner channels good (the model). OC wants a ramp-up
+ surf-across finale (banked wall reads random today). Rollercoaster P2
is a readability/routing loss (white-on-white, ended on last platform).
Endless needs ramp/visibility polish. Skypark vent needs post-dressing
retest. Speedrun good as-is (bhop bench).

Scope agreed: Slice A = waterfall entries across maps (faces bridge
their gaps: tops extended to the approach slabs grade-flush/buried,
bottoms daylight onto landings — jumping "over" lands further down the
SAME face instead of bypassing to the next floor). Faces: tutorial R1,
inter R1/R2/R3, adv R1/R2, precision P1/P2/P3. Then map-by-map guided
by these notes: OC finale (ramp up + surf across + finish line),
rollercoaster readability/routing, endless polish, skypark retest.

## d1363d5 roller R2 transport + R3 exposed (2026-10-08)
- R2 transfer restructured to transport (kicker flight lands Pool2 slab); mid-flight surf-meetings unmakable x13 rounds (face rate vs fall rate never converge).
- Root cause found: Pool2 (800 deep) buried R3's face (11u of 615u exposed) -> R3 unmountable by construction. Pool2 800->450 (ends -2050); R3 face runs exposed into Pool3 (grounds ~-2450).
- Doctrine: faces steeper than ~55 deg need near-vertical drop mounts (hop/run-off flights diverge, gap grew 126->167u on 60.5 deg); nub->face transition corner perches (land 20u past).
- Suite 708/708, smoke roller 3070u/8s. Reverted id-only regen churn on other maps + dev scenes.


## ed0aa04 endless visibility polish (2026-10-08)
- Playtest: white-on-white platforms, unreadable banks. Sun added (player was near-black under sky ambient); new 'platform' role -> mid-dark 0.55 via pure WorldMaterials.dark_base_for_role() (floor 0.0, obstacle 1.0, unknown 0.0); 4 guide signs (spawn loop, E/W bank side-entry telegraphs, platform route).
- Side banks (SR2 60 deg, SR3 50 deg) mount via side-entry along their 1600u length (frontal grade mounts diverge); pierce proven (spans cross grade, no stub walls). dev_endless.tscn bootstrap added + AGENTS.md list.
- Test lesson: baked scenes instantiate off-tree (_ready never runs) -> assert serialized sign_text, not label.text. Suite 730/730 (+22), endless smoke 1608u/8s, import clean.


## ebae6b7 skypark retest polish (2026-10-08)
- White-on-white ramps: (1) WorldMaterials._surface_bodies dead-code indent bug (append outside the SurfRamp guard) re-tinted ramps white � fixed; (2) skypark faces never SurfRamp*-prefixed -> glow dark-base path skipped them. Renamed all 7 faces.
- Placement (slice-A): face tops buried inside approach slabs (hops land further down the SAME face); 55-56 deg -> 53-54 deg; flush-merges at landing tops. Summit/Terraces -> platform role (mid-dark).
- Diagnostics load-bearing: baked scenes load through LevelLoader's threaded path (poll current_map); material dump needs str() on objects; label.text is empty off-tree.
- Suite 730/730, skypark smoke 3214u/8s (was 1964u). Endless banks get the same indent fix for free.


## bbc96fd skypark catchable surf loop (2026-10-08)
- Playtest: fast riders hopped OVER the 53-56 deg faces to the next platform; kickers felt dead.
- Math (load-bearing): a hopping rider (apex 56) intersects a 45+ deg face only ~x*=(m+vy0/vx)/0.0039 u along it -> 355-506u depending on speed. 280-330u faces at >50 deg were uncatchable BY CONSTRUCTION at speed.
- Fix: faces 571-599u at 46 deg -> riders land 60-90% down at any speed, surf the remainder, flush-merge onto the next platform. Terrace drops widened (T1 -620, T2 -1240, T3 -1290) to absorb. Tops buried inside approach slabs (slice-A).
- Kickers 26.6-26.7 -> 39-40 deg (vy ~308 at 450 u/s, apex ~59u): real zoom.
- Test lessons: rider position rests AT slab-top level (bands = top y, no +36); booster link tests must spawn OUTSIDE the sphere (teleport-in races body_entered).
- Suite 730/730, skypark smoke 3425u/8s. Re-confirmed: NEVER edit files via PowerShell (BOM + UTF-8 mojibake) � edit tool only.


## 665089b skypark kicker lips (2026-10-09)
- User: kickers do nothing on platforms; faces too steep to survive; kickers belong at ramp ends so you surf INTO the launch.
- Two trace-proven design kills: (1) jointed face->lip curves are NET-DESCENDING (sin integral over -46..+35) AND their sub-45 deg joints classify as GROUND (audit B3 cliff) -> riders porpoise off the arc (diag: vy zeroed, zero contact normal at C1); (2) face-into-uphill-wall projection zeroes sliding riders. The launch is the bhop-buffer jump at the lip � the engine's documented kicker behavior (ground-sliders zero, bhoppers launch).
- Shipped: 39 deg lips at each face end (EastFace/VentCatch -> fly onto T1 mid; T1FaceW -> T2 mid), terraces re-widened (T1 -730, T2 -1403, T3 -1453), kickers moved north of the west lip roof, kill -1700. New _test_skypark_chains: all 3 chains prove mount -> speed at lip (>400) -> launch (vy>250) -> landing band.
- Phase lottery is real: in-line continuation riders (L3/L5/L7) can land back ON the lip roof � kept as exit-only checks; the chains test owns the full-flight proof.
- Suite 750/750, skypark smoke 3437u/8s, import clean.


## c089ce4 skypark park rework: curves, sky route, loop (2026-10-09)
- User playtest: face-lips read as \/ V kinks (want gradual); kickers belong at ramp ends (surf INTO the launch); add sky ramps; no way back up = map ends; faces too slanted to survive.
- _kicker_end: 6-joint turn -46->+39 (1.7x overlapping boxes, M2 seam rules, 14/cos sink) + straight 39 deg lip. Riders surf down holding W (trace: ground accel carries the climb; the dip-catch at C1 keeps h), jump at the lip top (vy+300), land the next platform. Trace-proven again: smooth multi-joint CURVES don't launch - the sub-45 deg joints are GROUND (audit B3 cliff) and uphill walls zero sliding riders; the jump at the lip IS the kicker.
- Sky route (new): SkyLift1 bowl->SkyA (top -100) + SkyAFace->T2 express; SkyLift2 T1->SkyB (-850) + SkyBFace->T3; SkyLift3 T3->SkyC (-600); SkyLift4 SkyC->SkyB; SkyLift5 SkyB->bowl. Map loops; sky slabs carry surfable faces.
- Geometry: terraces widened (T1 -730 1200 deep, T2 -1403 1150 deep, T3 -1453 900 deep); Booster1 x=650->0 (x=650 bonked SkyA face underside at z -3560, wall-slid into the gap; x=400 was under KickerB; x=0 is the kickers' gap clear of lips). Kill -1700.
- Test lessons: rotated ramp boxes overhang gaps - probe with raycasts, don't hand-math midpoints; lift spheres hijack riders at lip zones (keep 40u+ clear); spawn test riders AT rest height (a 17u fall eats the 80ms jump buffer); setting player.velocity AFTER a jump press zeroes the impulse (set .z only); spawn above lift spheres with zero lateral velocity.
- Suite 798/798 (+48), skypark smoke 3326u/8s, import clean.

