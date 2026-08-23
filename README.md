# Velocity Engine

> A modular first-person movement engine for Godot 4 — and **Velocity**, its
> first game: bunny-hop / air-strafe / surf time trials.

Fixed 100 Hz Quake-style physics (Quake unit scale), a module-based movement
pipeline, Source-style surfing, CS-style air strafing, ghost replays, and
time-trial tooling. GDScript only, no engine forks.

## Status

Content complete (5 maps + 3 challenges) through the polish phase. Remaining
before v1.0: release build/export and Steam activation.

## Quick start

```sh
# Validate / import check
godot --headless --path . --editor --quit

# Run all tests (358 checks)
godot --headless --path . --script res://tests/test_runner.gd

# Play the tutorial
godot --path . scenes/world/dev_tutorial.tscn
```

Requires [Godot 4.x](https://godotengine.org/download). See
`docs/user_guide.md` for controls and how to play.

## Documentation

| Doc | Contents |
|---|---|
| [`docs/01_Master_Architecture.md`](docs/01_Master_Architecture.md) | Engine architecture, managers, module pipeline |
| [`docs/02_Gameplay_Systems.md`](docs/02_Gameplay_Systems.md) | Movement math & systems implementation |
| [`docs/03_Sprint_Plan.md`](docs/03_Sprint_Plan.md) | 30-sprint development roadmap |
| [`docs/user_guide.md`](docs/user_guide.md) | Player-facing guide |
| [`docs/changelog.md`](docs/changelog.md) | Feature changelog |
| [`docs/history.md`](docs/history.md) | Engineering log (what shipped, what broke) |
| [`docs/performance_profile.md`](docs/performance_profile.md) | Performance baseline & methodology |
| [`AGENTS.md`](AGENTS.md) | Operating rules for AI coding agents |

## Repository layout

```
scripts/movement/    Movement framework (never depends on game code)
scripts/game/        Game layer (timer, checkpoints, ghosts, maps logic)
scripts/managers/    Autoloaded services (SignalBus, Save, Audio, ...)
scenes/maps/         Time-trial maps + metadata resources
tests/test_runner.gd Canonical headless test entry point
tools/               SFX synthesis, benchmark harness
```

Dependency direction is strictly GAME → FRAMEWORK → ENGINE CORE → GODOT.
