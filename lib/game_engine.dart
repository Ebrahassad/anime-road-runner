// Game simulation for Anime Road Runner — 2D canvas edition.
//
// This engine holds ALL gameplay state and advances it once per frame via
// [update]. It intentionally knows nothing about how it is drawn: the
// painter (`game_painter.dart`) reads this state and projects it to screen
// space. That split is what makes the numbers here testable in principle and
// keeps rendering concerns out of the simulation.
import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;
import 'dart:ui' show Color;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'game_math.dart' as gm;
import 'l10n.dart';
import 'models.dart';

enum Phase { menu, playing, crashed }

/// Volume presets, indexed 0/1/2 for off/low/high — matches the
/// `off` / `low` / `high` strings already in `l10n.dart`.
const List<double> kVolumes = <double>[0.0, 0.55, 1.0];

class GameEngine {
  GameEngine() {
    ready = Future.wait(<Future<void>>[_loadPrefs(), _loadCharacterImage()])
        .then((_) {});
  }

  /// Resolves once persisted prefs (leaderboard, volume) *and* the
  /// character sprite have loaded — `main.dart` gates the first frame on
  /// this so the game never flashes the vector-fallback player for a beat
  /// before the real art pops in.
  late final Future<void> ready;

  /// The real character artwork (back view, matches the camera-behind-the-
  /// runner framing). Null only if the asset failed to decode, in which
  /// case `GamePainter` falls back to a drawn placeholder rather than
  /// showing nothing.
  ui.Image? characterImage;

  Future<void> _loadCharacterImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/character/runner.png');
      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frame = await codec.getNextFrame();
      characterImage = frame.image;
    } catch (_) {
      characterImage = null;
    }
  }

  // --- persistent prefs -----------------------------------------------
  final List<LeaderboardEntry> leaderboard = <LeaderboardEntry>[];
  int volumeIndex = 2;
  bool _prefsLoaded = false;

  int get bestScore =>
      leaderboard.isEmpty ? 0 : leaderboard.map((e) => e.score).reduce(math.max);

  Future<void> _loadPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList('leaderboard.v1') ?? <String>[];
      leaderboard
        ..clear()
        ..addAll(raw.map(LeaderboardEntry.decode).whereType<LeaderboardEntry>());
      volumeIndex = prefs.getInt('volume.v1') ?? 2;
      final String? lang = prefs.getString('language.v1');
      if (lang == 'ar') {
        AppStrings.language.value = AppLanguage.ar;
      } else if (lang == 'en') {
        AppStrings.language.value = AppLanguage.en;
      }
    } catch (_) {
      // Corrupt/missing prefs degrade silently to empty board / full volume.
    }
    _prefsLoaded = true;
  }

  Future<void> setVolumeIndex(int i) async {
    volumeIndex = i.clamp(0, kVolumes.length - 1).toInt();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('volume.v1', volumeIndex);
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    AppStrings.language.value = lang;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language.v1', lang == AppLanguage.ar ? 'ar' : 'en');
    } catch (_) {}
  }

  bool get isNewBest =>
      score > 0 && (leaderboard.length < 5 || score > leaderboard.last.score);

  Future<void> submitScore(String rawName) async {
    final String name = rawName.trim().isEmpty ? 'YOU' : rawName.trim().toUpperCase();
    leaderboard.add(LeaderboardEntry(score, name.length > 12 ? name.substring(0, 12) : name));
    leaderboard.sort((a, b) => b.score.compareTo(a.score));
    if (leaderboard.length > 5) leaderboard.removeRange(5, leaderboard.length);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'leaderboard.v1',
        leaderboard.map((e) => e.encode()).toList(),
      );
    } catch (_) {}
  }

  // --- audio -------------------------------------------------------------
  final AudioPlayer _sfxCoin = AudioPlayer();
  final AudioPlayer _sfxCrash = AudioPlayer();
  final AudioPlayer _sfxJump = AudioPlayer();
  final AudioPlayer _sfxPower = AudioPlayer();

  Future<void> _play(AudioPlayer p, String asset) async {
    final double vol = kVolumes[volumeIndex];
    if (vol <= 0) return;
    try {
      await p.stop();
      await p.play(AssetSource('sfx/$asset'), volume: vol);
    } catch (_) {
      // Missing/broken audio device must never take gameplay down with it.
    }
  }

  // --- run state -----------------------------------------------------
  Phase phase = Phase.menu;
  final math.Random _rng = math.Random();

  int laneIndex = 1; // 0=left, 1=centre, 2=right
  double laneVisual = 0; // smoothed world-x of the player, for rendering
  int get playerLane => kLanes[laneIndex];

  bool jumping = false;
  double jumpElapsed = 0;
  static const double jumpDuration = 0.62;
  double get jumpT => (jumpElapsed / jumpDuration).clamp(0.0, 1.0).toDouble();
  double get jumpHeight => jumping || jumpT < 1 ? math.sin(math.pi * jumpT) : 0.0;

  double elapsed = 0;
  double speed = 0;
  static const double _baseSpeed = 0.34;
  static const double _maxSpeed = 0.95;
  static const double _rampPerSec = 0.012;

  int score = 0;
  double _distanceAccum = 0;
  int scoreMultiplier = 1;

  bool shieldActive = false;
  double magnetTimeLeft = 0;
  double doubleScoreTimeLeft = 0;

  double _spawnTimer = 0.9;

  final List<Obstacle> obstacles = <Obstacle>[];
  final List<Coin> coins = <Coin>[];
  final List<PowerUp> powerUps = <PowerUp>[];
  final List<Particle> particles = <Particle>[];
  final List<Popup> popups = <Popup>[];

  bool get prefsLoaded => _prefsLoaded;

  void startRun() {
    phase = Phase.playing;
    laneIndex = 1;
    laneVisual = 0;
    jumping = false;
    jumpElapsed = 0;
    elapsed = 0;
    speed = _baseSpeed;
    score = 0;
    _distanceAccum = 0;
    scoreMultiplier = 1;
    shieldActive = false;
    magnetTimeLeft = 0;
    doubleScoreTimeLeft = 0;
    _spawnTimer = 0.9;
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    particles.clear();
    popups.clear();
  }

  void returnToMenu() {
    phase = Phase.menu;
  }

  // --- input -----------------------------------------------------------
  void moveLeft() {
    if (phase != Phase.playing) return;
    laneIndex = (laneIndex - 1).clamp(0, 2).toInt();
  }

  void moveRight() {
    if (phase != Phase.playing) return;
    laneIndex = (laneIndex + 1).clamp(0, 2).toInt();
  }

  void jump() {
    if (phase != Phase.playing || jumping) return;
    jumping = true;
    jumpElapsed = 0;
    unawaited(_play(_sfxJump, 'jump.wav'));
  }

  // --- per-frame update --------------------------------------------------
  void update(double rawDt) {
    final double dt = gm.clampDt(rawDt, 0.05);

    _updateParticles(dt);
    _updatePopups(dt);

    if (phase != Phase.playing) return;

    elapsed += dt;
    speed = gm.speedAt(elapsed, base: _baseSpeed, max: _maxSpeed, rampPerSec: _rampPerSec);

    laneVisual += (playerLane.toDouble() - laneVisual) * gm.smoothing(14, dt);

    if (jumping) {
      jumpElapsed += dt;
      if (jumpElapsed >= jumpDuration) {
        jumping = false;
        jumpElapsed = 0;
      }
    }

    if (magnetTimeLeft > 0) magnetTimeLeft = math.max(0.0, magnetTimeLeft - dt);
    if (doubleScoreTimeLeft > 0) {
      doubleScoreTimeLeft = math.max(0.0, doubleScoreTimeLeft - dt);
    }
    scoreMultiplier = doubleScoreTimeLeft > 0 ? 2 : 1;

    _distanceAccum += speed * dt * 12;
    if (_distanceAccum >= 1) {
      final int gained = _distanceAccum.floor();
      score += gained * scoreMultiplier;
      _distanceAccum -= gained;
    }

    _advanceTravelers(dt);
    _spawn(dt);
  }

  void _advanceTravelers(double dt) {
    final double rate = speed * dt * 0.62;
    const double collideT = 0.93;

    for (final Obstacle o in obstacles) {
      final double before = o.t;
      o.t += rate;
      if (!o.passed && before < collideT && o.t >= collideT) {
        o.passed = true;
        if (o.lane == playerLane) {
          final bool jumpedOver = o.kind == ObstacleKind.crate && jumping;
          if (!jumpedOver) _onHitObstacle();
        }
      }
      if (o.t > 1.2) o.dead = true;
    }
    obstacles.removeWhere((o) => o.dead);

    const double coinT = 0.86;
    for (final Coin c in coins) {
      final double before = c.t;
      c.t += rate;
      final bool collectable = magnetTimeLeft > 0 || c.lane == playerLane;
      if (!c.collected && before < coinT && c.t >= coinT && collectable) {
        c.collected = true;
        c.dead = true;
        score += 10 * scoreMultiplier;
        unawaited(_play(_sfxCoin, 'coin.wav'));
        _spawnPopup('+${10 * scoreMultiplier}', c.lane, gold: true);
      }
      if (c.t > 1.2) c.dead = true;
    }
    coins.removeWhere((c) => c.dead);

    const double powerT = 0.9;
    for (final PowerUp p in powerUps) {
      final double before = p.t;
      p.t += rate;
      if (!p.collected && before < powerT && p.t >= powerT && p.lane == playerLane) {
        p.collected = true;
        p.dead = true;
        _activatePower(p.kind);
        unawaited(_play(_sfxPower, 'power.wav'));
      }
      if (p.t > 1.2) p.dead = true;
    }
    powerUps.removeWhere((p) => p.dead);
  }

  void _activatePower(PowerKind kind) {
    switch (kind) {
      case PowerKind.magnet:
        magnetTimeLeft = 7;
        _spawnPopup('MAGNET', playerLane, gold: false);
        break;
      case PowerKind.shield:
        shieldActive = true;
        _spawnPopup('SHIELD', playerLane, gold: false);
        break;
      case PowerKind.doubleScore:
        doubleScoreTimeLeft = 8;
        _spawnPopup('×2', playerLane, gold: false);
        break;
    }
  }

  void _onHitObstacle() {
    if (shieldActive) {
      shieldActive = false;
      _spawnBurst(playerLane, const Color(0xFF4FD1C5));
      _spawnPopup('SHIELD', playerLane, gold: false);
      return;
    }
    phase = Phase.crashed;
    _spawnBurst(playerLane, const Color(0xFFE0533D));
    unawaited(_play(_sfxCrash, 'crash.wav'));
  }

  void _spawn(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;

    final double interval = gm.lerpD(1.05, 0.55, (speed - _baseSpeed) / (_maxSpeed - _baseSpeed));
    _spawnTimer = interval * (0.85 + _rng.nextDouble() * 0.3);

    final double roll = _rng.nextDouble();
    if (roll < 0.62) {
      _spawnObstacle();
    } else if (roll < 0.93) {
      _spawnCoinRow();
    } else {
      _spawnPowerUp();
    }
  }

  void _spawnObstacle() {
    // Fairness guard: never let two-plus lanes already be "walled" near
    // spawn — always leave at least one lane open to the player.
    final int recentLanes =
        obstacles.where((o) => o.t < 0.45).map((o) => o.lane).toSet().length;
    if (recentLanes >= 2) return;

    final List<int> free = kLanes
        .where((l) => !obstacles.any((o) => o.t < 0.45 && o.lane == l))
        .toList();
    if (free.isEmpty) return;
    final int lane = free[_rng.nextInt(free.length)];
    final ObstacleKind kind =
        _rng.nextDouble() < 0.72 ? ObstacleKind.crate : ObstacleKind.barrier;
    obstacles.add(Obstacle(lane: lane, t: 0, kind: kind));
  }

  void _spawnCoinRow() {
    final int lane = kLanes[_rng.nextInt(3)];
    final int count = 3 + _rng.nextInt(4);
    for (int i = 0; i < count; i++) {
      coins.add(Coin(lane: lane, t: -i * 0.045));
    }
  }

  void _spawnPowerUp() {
    final int lane = kLanes[_rng.nextInt(3)];
    final PowerKind kind = PowerKind.values[_rng.nextInt(PowerKind.values.length)];
    powerUps.add(PowerUp(lane: lane, t: 0, kind: kind));
  }

  // --- particles / popups --------------------------------------------
  void _spawnPopup(String text, int lane, {required bool gold}) {
    popups.add(Popup(
      anchorLane: lane.toDouble(),
      text: text,
      color: gold ? const Color(0xFFFFC93C) : const Color(0xFFFFFFFF),
    ));
  }

  void _spawnBurst(int lane, Color color) {
    for (int i = 0; i < 18; i++) {
      final double angle = _rng.nextDouble() * math.pi * 2;
      final double speedPx = 70 + _rng.nextDouble() * 160;
      particles.add(Particle(
        anchorLane: lane.toDouble(),
        vx: math.cos(angle) * speedPx,
        vy: math.sin(angle) * speedPx - 90,
        color: color,
        life: 0.5 + _rng.nextDouble() * 0.4,
      ));
    }
  }

  void _updateParticles(double dt) {
    for (final Particle p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 480 * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.dead);
  }

  void _updatePopups(double dt) {
    for (final Popup p in popups) {
      p.y -= 46 * dt;
      p.life -= dt;
    }
    popups.removeWhere((p) => p.dead);
  }

  void dispose() {
    _sfxCoin.dispose();
    _sfxCrash.dispose();
    _sfxJump.dispose();
    _sfxPower.dispose();
  }
}
