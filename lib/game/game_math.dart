/// Pure, engine-free gameplay math for Anime Road Runner.
///
/// Everything here is a plain function over numbers — no Flutter, no
/// rendering, no state, no I/O. That keeps it reachable from a plain
/// `dart:test` / `flutter_test` unit test with nothing else spun up.
library;

import 'dart:math' as math;

/// World x offset of a lane index. Lane `0` is centre, negative lanes sit to
/// the left, positive lanes to the right.
double laneX(int lane, double laneWidth) => lane * laneWidth;

/// Frame-rate-independent smoothing factor for an exponential approach.
///
/// Use `value += (target - value) * smoothing(rate, dt)` rather than a raw
/// lerp constant: a raw factor makes the approach speed depend on the frame
/// rate, so the same code feels different at 30 and 120 fps.
double smoothing(double rate, double dt) => 1 - math.exp(-rate * dt);

/// Whether two centres on one axis are closer than the sum of their half
/// extents — a 1D overlap test, used per-axis for a simple AABB check.
bool overlaps1D(double centreA, double centreB, double halfSum) =>
    (centreA - centreB).abs() < halfSum;

/// Difficulty ramp: speed rises linearly with elapsed time and then holds.
double speedAt(
  double elapsed, {
  required double base,
  required double max,
  required double rampPerSec,
}) =>
    math.min(max, base + elapsed * rampPerSec);

/// Clamps a frame delta so a hitch (a GC pause, a window resize, the tab
/// coming back from the background) cannot teleport the runner through an
/// obstacle. Bounding dt is cheaper and far more predictable than running a
/// sub-stepped integrator.
double clampDt(double dt, double maxDt) => dt > maxDt ? maxDt : dt;

/// Linear interpolation, kept local so this file has zero Flutter imports.
double lerpD(double a, double b, double t) => a + (b - a) * t;

/// Clamps [v] into `[lo, hi]`.
double clampD(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// Eases `t` (expected in `[0, 1]`) with a quadratic curve, used to make
/// far-away world objects approach slowly and accelerate toward the camera —
/// the classic perspective-runner "distance" feel.
double easeInQuad(double t) => t * t;

/// English ordinal for a leaderboard position: 1 -> `1st`, 12 -> `12th`.
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
