# Velocity — User Guide

*First-person bunny-hop / air-strafe / surf time trials, built on the Velocity Engine.*

---

## Getting the game

Velocity is not yet distributed; run it from source:

1. Install [Godot 4.x](https://godotengine.org/download) (4.3 or newer).
2. Clone this repository.
3. Launch the game:

```sh
godot --path .
```

The main menu lets you pick a map and start racing. For one-off testing you
can still launch maps directly:

```sh
godot --path . scenes/world/dev_tutorial.tscn
```

---

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move |
| Mouse | Look |
| `Space` | Jump (hold to auto-bunnyhop on every landing) |
| `R` | Restart from last checkpoint |
| `F1` | Debug overlay (speed, state, velocity vector) |
| `Esc` | Pause menu (resume / restart / settings / quit) |

The mouse is captured while playing. Esc opens the pause menu and releases
the mouse; click Resume (or press Esc again) to go back — the mouse
re-captures automatically.

---

## Movement school

Velocity runs its simulation at a fixed **100 Hz** with Quake-style physics
(1 unit = 1 Quake unit). Three skills matter:

### 1. Bunny hopping

Jumping the instant you land skips most ground friction and keeps your speed.
Hold `Space` — the game auto-jumps on every landing for you, with zero
speed penalty versus perfect manual timing (CS2 autobhop parity). Ground
running is capped at 320 u/s; bhopping preserves momentum and strafing
builds more.

### 2. Air strafing

While airborne you gain speed by turning *with* your strafe key: hold `W+A`
and smoothly sweep the mouse left, or `W+D` sweeping right. Pure forward
(`W` alone) never gains speed. This is authentic Quake/CS physics — smooth,
continuous mouse movement beats flicks.

### 3. Surfing

Steep ramps (roughly 45°+) act like slideable walls. Land on one and gravity
converts into downhill speed. Steer with `A/D` against the ramp plus mouse;
you cannot jump off mid-surf — ride it to the end or slide off. Ramps glow
cyan while you ride them.

**Steeper is harder to steer, not harder to grip.** Maps progress 48° →
56° → 60° → 65° → 70° faces; slow riders stick to all of them, but fast
steep faces punish sloppy lines instantly. Enter with speed for control,
carve early, and never hold `W` into the ramp (it kills grip). Grinding a
wall or lip at speed won't brake you; standing still against one will.

## Launching off a ramp

Ramps can't be climbed — a 56° face turns your speed into height at
roughly 80% per unit, exactly like CS2 (same 56° surf ramps). What works
and what's physics-correct:

- **Traverse DOWN or ACROSS the face** — most of your line's speed comes
  from the descent, and you preserve through the wall-ride. Carving
  directly UP the face is a trade, not a launch: you spend speed buying
  height, and exit with whatever's left.
- **Launch if you bend the turn out of the wall into the inward falling
  arc** — that's the same trajectory as CS2's "bounce off your wall
  height".
- **Kickers** (short shallow ramps angled 20–35° into the path, see the
  Kicker on Rollercoaster) are where upward flight really lives: your
  flat-line momentum meets the kicker wedge and the frictionless surface
  converts it into an arc. On maps without one, create upward arcs by
  exiting a face with your velocity already angled up-off it (work the
  last meters down the face so your exit has both fall AND forward)
  instead of trying to fire through the top edge.
- **Flying between ramps** is the same physics as the launch: you keep your
  ballistic from a kicker/face exit and aim it. A 65° steep face falls away
  faster than gravity catches, so use a down-line (or kicker arc) aimed at
  it, never a flat cruise.

Bench check (beginner V-channel, with-debug-timer (bhop cruise) runs):

|entry speed|exit speed|
|---|---|
|257 u/s|338 u/s|
|459 u/s|486 u/s|
|706 u/s|718 u/s|

Conserves/gains at all entry speeds — if your speed is collapsing, check
you're not headfirsting the corner of the wall's end cap (the strictly
around-90° edge where the surf plane projects against your forward path):
arcs are reliable, adjust course so the corner is never vertical to you.

**Speed is everything.** The HUD speedometer colors by tier: gray → white →
yellow (400+) → orange (600+) → red (800+). Good lines mix all three skills.

---

## Maps

| Map | Difficulty | Teaches / tests |
|---|---|---|
| Tutorial | ★ | Bhop, air strafe, surf basics with signs |
| Beginner | ★★ | ~30s line, gentle ramps |
| Intermediate | ★★★ | Mixed bhop/surf, ~60s, kill-plane gaps |
| Advanced | ★★★★ | High-speed 50–70° ramps, ~90s expert line |
| Obstacle Course | ★★★ | Moving walls, jump puzzles |
| Precision Surf | ★★★★ | Tiny ramps, exact landing angles |
| Speed Run | ★★★★ | One continuous full-send line |

Timer starts when you leave the start platform and stops at the finish.
Checkpoints save progress: falling off the map respawns you at the last one
(press `R` to go back manually).

### Personal bests & ghosts

Your best time per map is saved automatically. Beat your PB and a translucent
ghost of that record run replays beside you next attempt.

---

## Settings

Reach Settings from the pause menu (`Esc`) or the main menu.

- **Graphics** — fullscreen, vsync, FPS cap, windowed resolution
- **Audio** — Master / Music / SFX volume (live preview)
- **Input** — rebind any key (click a binding, press a key; conflicts rejected)
- **Gameplay** — debug overlay toggle, auto-save ghost toggle
- **Reset to Defaults** restores factory settings

### Music stations

Drop royalty-free tracks into `assets/audio/music/` as `<station>.ogg` or
`.wav` (e.g. `jazz.ogg`) and they appear in the Audio tab's station dropdown.

---

## Achievements

First Jump · First BHop · First Surf · First PB · Beat 300 u/s · Beat 600 u/s

They unlock once (persisted between sessions), toast in-game with a chime,
and will mirror to Steam at release.

---

*For engine internals see `docs/01_Master_Architecture.md`; release notes live
in `docs/changelog.md`.*
