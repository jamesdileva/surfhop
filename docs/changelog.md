# Velocity — Changelog

Feature-level history. Session-by-session engineering notes live in
`docs/history.md`.

---

## Phase 5 — Polish & Release (Sprints 24–29)

### Sprint 28 — Steam integration (local mode)
- Achievement system: First Jump, First BHop, First Surf, First PB,
  Beat 300 u/s, Beat 600 u/s; once-only unlocks persisted across sessions.
- In-game achievement toasts + synthesized unlock chime.
- Cloud-save and leaderboard seams behind `SteamManager`; real activation
  deferred to release (GodotSteam GDExtension + AppID required).

### Sprint 27 — Optimization
- Built-in engine physics interpolation for smooth visuals above the 100 Hz
  simulation rate, with teleport-safe resets on respawns.
- Hot-path caching in surf detection and VFX (bit-identical movement,
  verified by the determinism suite).
- Repeatable headless benchmark harness; performance baseline documented in
  `docs/performance_profile.md`.

### Sprint 26 — Settings menu
- Four-tab settings overlay: Graphics (fullscreen/vsync/fps cap/resolution),
  Audio (live-preview volume sliders), Input (full rebinding with conflict
  rejection), Gameplay (debug, ghost auto-save).
- All settings apply live and persist immediately; Reset to Defaults.

### Sprint 25 — Visual effects
- Landing dust scaled by impact speed; takeoff puffs on any ground exit.
- Speed trails above 600 u/s; surf ramps glow cyan with rider speed.
- All effects togglable via the `video/vfx_enabled` setting.

### Sprint 24 — Audio
- Full AudioManager: Music/SFX/UI buses, event-driven footsteps, jump/land
  sounds, surf loop with speed-scaled pitch, finish jingle, menu sounds.
- Music-station system (`audio/music_track` setting) ready for user tracks.
- All placeholder sounds synthesized in-repo (zero licensing concerns).

## Phase 4 — Content (Sprints 19–23)

- **Tutorial** map teaching bhop, air strafing, and surfing step by step.
- **Beginner / Intermediate / Advanced** time-trial maps (~30/60/90s expert
  times, escalating ramp angles, checkpoints, kill-plane gaps).
- Three **Challenge maps**: Obstacle Course (moving walls), Precision Surf,
  Speed Run.

## Phase 3 — Gameplay (Sprints 13–18)

- Race timer with start/finish triggers, PB tracking, pause-safe timing.
- Checkpoints with respawn, split times, kill-plane recovery.
- Map loading with metadata (difficulty, config presets, thumbnails).
- HUD: tier-colored speedometer, timer, PB, checkpoint progress, FPS, debug line.
- Save system: settings, PB records, ghost replays under `user://`.
- PB ghost recording at 100 Hz with translucent playback model.

## Phase 2 — Movement Engine (Sprints 6–12)

- Quake-style ground physics: acceleration, friction with stop-speed, 320 u/s cap.
- Jumping with coyote time; no double jump.
- Bunny hopping: input buffering, friction skip on buffered landings,
  auto-bhop hold-jump.
- CS-style air strafing (HL air-acceleration variant; pure-A circle strafe works).
- Source-style surfing: wall-contact ramp model, velocity projection,
  anti-stuck push, clean exit boosts.
- Fixed-tick determinism verified (identical inputs → identical runs).
- Debug overlay (F1): state, speed, velocity vector, slope limit.

## Phase 1 — Foundation (Sprints 1–5)

- Godot 4 project at a fixed 100 Hz physics tick, Quake unit scale.
- Manager architecture (SignalBus + autoloaded services) and module-based
  movement pipeline.
- Full input system: rebindable keys with persistence and conflict detection.
- First-person camera: sensitivity/invert settings, pitch clamp.

---

*Upcoming: Sprint 30 — v1.0 release build.*
