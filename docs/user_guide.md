# Velocity — User Guide

*First-person bunny-hop / air-strafe / surf time trials, built on the Velocity Engine.*

---

## Getting the game

Velocity is not yet distributed; run it from source:

1. Install [Godot 4.x](https://godotengine.org/download) (4.3 or newer).
2. Clone this repository.
3. Launch any map directly:

```sh
godot --path . scenes/world/dev_tutorial.tscn
```

(Once a main menu ships, `godot --path .` launches the game directly.)

---

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move |
| Mouse | Look |
| `Space` | Jump (hold to auto-bunnyhop on every landing) |
| `R` | Restart from last checkpoint |
| `F1` | Debug overlay (speed, state, velocity vector) |
| `Esc` | Open/close Settings |

The mouse is captured while playing. Esc releases it into the settings menu;
click anywhere after closing to re-capture.

---

## Movement school

Velocity runs its simulation at a fixed **100 Hz** with Quake-style physics
(1 unit = 1 Quake unit). Three skills matter:

### 1. Bunny hopping

Jumping the instant you land skips most ground friction and keeps your speed.
Hold `Space` — the game auto-jumps on every landing for you. Ground running is
capped at 320 u/s; bhopping preserves momentum and strafing builds more.

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

## Settings (`Esc`)

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
