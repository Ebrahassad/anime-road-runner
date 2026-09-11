import 'dart:ui' show Color;

/// The three lanes the player can occupy. Values are also used directly as
/// the lane's world-x multiplier (see `game_math.laneX`).
const List<int> kLanes = <int>[-1, 0, 1];

enum ObstacleKind {
  /// A low crate: avoidable by changing lane OR by jumping over it.
  crate,

  /// A tall barrier: only avoidable by changing lane; jumping does not help.
  barrier,
}

enum PowerKind { magnet, shield, doubleScore }

/// A world object's progress from spawn to the player.
///
/// `t == 0` is the moment it spawns at the horizon; `t == 1` is where the
/// player stands. Everything walks `t` up at a shared per-frame rate derived
/// from the current game speed.
abstract class _Traveler {
  _Traveler({required this.lane, required this.t});
  final int lane;
  double t;
  bool dead = false;
}

class Obstacle extends _Traveler {
  Obstacle({required super.lane, required super.t, required this.kind});
  final ObstacleKind kind;
  bool passed = false;
}

class Coin extends _Traveler {
  Coin({required super.lane, required super.t});
  bool collected = false;
}

class PowerUp extends _Traveler {
  PowerUp({required super.lane, required super.t, required this.kind});
  final PowerKind kind;
  bool collected = false;
}

/// A short-lived burst particle (coin sparkle, crash debris).
///
/// [anchorLane] picks the world point the painter projects as "home"; [x]/[y]
/// are a pure pixel offset from that projected point, animated by the engine
/// in plain screen-pixel physics so the painter never has to know how
/// particles move, only where they are anchored.
class Particle {
  Particle({
    required this.anchorLane,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
  })  : x = 0,
        y = 0,
        maxLife = life;

  final double anchorLane;
  double x, y, vx, vy;
  double life;
  final double maxLife;
  final Color color;

  bool get dead => life <= 0;
}

/// A rising/fading "+10" style score popup. [anchorLane] picks the world
/// point the painter projects as its origin; [y] is a pixel offset that
/// rises (goes negative) over the popup's life.
class Popup {
  Popup({
    required this.anchorLane,
    required this.text,
    this.color = const Color(0xFFFFFFFF),
    this.life = 0.9,
  })  : y = 0,
        maxLife = life;

  final double anchorLane;
  double y;
  double life;
  final double maxLife;
  final String text;
  final Color color;

  bool get dead => life <= 0;
}

class LeaderboardEntry {
  const LeaderboardEntry(this.score, this.name);
  final int score;
  final String name;

  String encode() => '$score|$name';

  static LeaderboardEntry? decode(String raw) {
    final int i = raw.indexOf('|');
    if (i < 0) return null;
    final int? score = int.tryParse(raw.substring(0, i));
    if (score == null) return null;
    return LeaderboardEntry(score, raw.substring(i + 1));
  }
}
