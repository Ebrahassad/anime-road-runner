# CLAUDE.md

Guidance for Claude Code (or any future agent) working in this repo.

## What this is, and why it looks different from its git history

A 3-lane 2D endless runner, drawn entirely with Flutter's standard
`CustomPainter`/`Canvas` API. **This is a full rewrite of what was previously
a 3D game built directly against `flutter_scene` (Flutter GPU / Impeller).**

That rewrite happened because the 3D build had a persistent, unfixed bug:
the app launched, the menu UI rendered, gameplay logic ran (score ticked
up, diagnostics logged `[BuildWorld] road tiles done (24 loaded)`) — but
the actual 3D scene never drew anything. Only a flat sky-gradient
background ever appeared on the affected device. Two in-app fix attempts
(forcing Impeller, native-assets build config) made no difference, and the
CI workflow's own comments record a second, compounding cause: the
Native Assets build hook that `flutter_scene` needs to convert `.glb`
models and bake materials was silently never running on fresh CI runners.
Given that history, rebuilding the rendering path on plain Canvas — which
has no experimental GPU backend, no native-assets build step, and draws
identically on every device Flutter supports — was the reliable fix,
versus continuing to debug an experimental rendering pipeline blind (no
on-device access, no build tooling in this environment either).

If you're tempted to reach for `flutter_scene`/Flutter GPU again: don't,
unless you can test on the actual failing device first. Nothing in the
current design needs it.

## Architecture

Six files, each with one job:

- `lib/main.dart` — entry point, `RunnerApp`, `GamePage` (owns the game
  loop via a `Ticker`, keyboard + swipe input), menu/settings/HUD/game-over
  UI. Ordinary Flutter widgets throughout.
- `lib/game_engine.dart` — `GameEngine`: all simulation state (player lane,
  jump arc, spawns, collisions, score, power-ups, particles/popups) plus
  persistence (`shared_preferences`: leaderboard, volume, language) and SFX
  (`audioplayers`). Knows nothing about pixels — `update(dt)` just advances
  numbers. `GamePage` drives it with a `Ticker` and calls `setState` every
  frame; the `CustomPaint` below it re-reads the same mutable `GameEngine`
  instance each rebuild.
- `lib/game_painter.dart` — `GamePainter extends CustomPainter`: the only
  file that touches `Canvas`. Projects each world object's `(lane, t)` —
  `t` is travel progress from spawn (`0`, at the horizon) to the player
  (`1`) — to a screen point + scale via `_project()`, then draws sky,
  road, obstacles, coins, power-ups, the player sprite, particles and
  popups, in that back-to-front order (world objects are depth-sorted by
  `t` first).
- `lib/models.dart` — plain data classes: `Obstacle`/`Coin`/`PowerUp`
  (share a `_Traveler` base: `lane`, `t`, `dead`), `Particle`, `Popup`,
  `LeaderboardEntry`.
- `lib/game_math.dart` — pure, Flutter-free math (`smoothing`, `speedAt`,
  `clampDt`, `lerpD`, `ordinal`, etc.), unit-tested in
  `test/game_math_test.dart`. Keep it that way: no Flutter/GPU imports here,
  ever — it's the only code in this repo a headless `flutter_test` run can
  actually exercise without standing up a widget tree.
- `lib/l10n.dart` — tiny in-app EN/AR string table + `Directionality`
  override. Unrelated to the rendering rewrite; carried over as-is.

## Known Dart gotchas that bit this rewrite once already

- **`num.clamp(lo, hi)` returns `num`, not the receiver's type.** `int` does
  not override it. `(x).clamp(0, 2)` assigned to an `int`/`double` variable
  is a compile error without an explicit `.toInt()`/`.toDouble()`. Every
  `.clamp(` call site in this repo already carries that suffix — keep doing
  that for any new one, or use `game_math.clampD`, which is a plain
  double-only helper with no such trap.
- Conditional expressions (`cond ? a : b`) and generic-`T` calls
  (`math.min`/`math.max`) infer their result type from **both** branches —
  mixing a bare `0` (int) with a `double` branch is usually fine because
  Dart treats an integer literal as `double` when the context demands it,
  but don't rely on that inside a nested method call the way `.clamp`'s
  fixed `num` return defeats it. When in doubt, write `0.0`.

## Persistence

`shared_preferences`, three keys, all loaded once in `GameEngine._loadPrefs()`
(awaited via `GameEngine.ready` before the first frame the game logic
depends on it — see `_RunnerAppState` in `main.dart`):

- `leaderboard.v1` — `List<String>`, each `"$score|$name"`, top 5,
  desc-sorted. Same encoding the old 3D build used, so old saved scores
  still parse.
- `volume.v1` — `int` index into `kVolumes` (`game_engine.dart`): 0/1/2 for
  off/low/high.
- `language.v1` — `"en"` or `"ar"`.

All three loaders swallow errors (corrupt/missing prefs silently degrade to
empty board / full volume / system-locale language) rather than crashing.

## Assets

Only `assets/sfx/*.wav` (coin/crash/jump/power) and `assets/icon/` remain.
The old `.glb` models and `assets/road/` / `assets/city_props/` GLB
scenery are gone — this build has nothing that loads `.glb` files. If you
see a stale reference to them anywhere, it's leftover from the 3D build;
delete it.

## CI

`.github/workflows/build-apk.yml` builds on the **stable** channel now
(previously `master`, and previously required, because `flutter_scene`
needed bleeding-edge Flutter GPU support). The old "enable native assets"
step is gone for the same reason — nothing in this build uses Dart Native
Assets. `.fvmrc` / `.metadata` were updated to match for local `fvm`
users.
