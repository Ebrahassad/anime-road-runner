// Renders `GameEngine` state to a `Canvas`. Deliberately plain
// `dart:ui`/`Canvas` drawing only — no `flutter_scene`, no Flutter GPU, no
// native-assets build step. That is the fix: a Canvas paints the same way on
// every device Flutter runs on, with no experimental rendering backend in
// the path between "the game says draw a box" and "a box is on screen".
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_engine.dart';
import 'game_math.dart' as gm;
import '../models/models.dart';

const Color _skyTop = Color(0xFF3E8FE0);
const Color _skyBottom = Color(0xFFAEE0F5);
const Color _grass = Color(0xFF6FBF6A);
const Color _grassDark = Color(0xFF5AA655);
const Color _road = Color(0xFF3B4252);
const Color _roadLight = Color(0xFF4C5768);
const Color _roadLine = Color(0xFFF4E9C9);
const Color _dashTeal = Color(0xFF4FD1C5);
const Color _dashGold = Color(0xFFFFC93C);
const Color _crateColor = Color(0xFFB5834B);
const Color _barrierColor = Color(0xFFE0533D);

class GamePainter extends CustomPainter {
  GamePainter(this.engine, this.repaintTick) : super(repaint: null);

  final GameEngine engine;
  // Bumped every frame by the caller so `shouldRepaint` always returns true;
  // kept as a field (rather than relying on identity) so intent is explicit.
  final int repaintTick;

  double _horizonY(Size size) => size.height * 0.34;

  /// The "standing plane" — where the player and near-field objects sit.
  /// Kept above the physical screen bottom (rather than at `size.height`)
  /// so the character sprite, its shadow, and the HUD's bottom safe-area
  /// all stay clear of gesture-nav bars instead of being clipped off the
  /// edge of the screen.
  double _groundY(Size size) => size.height * 0.82;

  double _easeT(double t) {
    final double c = t.clamp(0.0, 1.15).toDouble();
    return c * c;
  }

  /// Projects a lane value (can be fractional, e.g. the smoothed player
  /// lane) and a travel progress `t` (`0` = spawn/horizon, `1` = player) to
  /// a screen point + a uniform scale for sprite sizing at that depth.
  ({Offset pos, double scale, double halfW}) _project(
    Size size,
    double lane,
    double t,
  ) {
    final double horizonY = _horizonY(size);
    final double e = _easeT(t);
    final double y = gm.lerpD(horizonY, _groundY(size), e);
    final double halfW = gm.lerpD(18, size.width * 0.60, e);
    final double scale = gm.lerpD(0.16, 1.0, e);
    final double x = size.width / 2 + lane * halfW * 0.62;
    return (pos: Offset(x, y), scale: scale, halfW: halfW);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = _horizonY(size);
    _paintSky(canvas, size, horizonY);
    _paintGround(canvas, size, horizonY);
    _paintRoad(canvas, size, horizonY);

    // Depth-sort every world object (far -> near) so nearer sprites overlap
    // farther ones correctly, regardless of which list they came from.
    final List<_Drawable> drawables = <_Drawable>[
      ...engine.obstacles.map((o) => _Drawable(o.t, (c) => _paintObstacle(c, size, o))),
      ...engine.coins.map((c) => _Drawable(c.t, (cv) => _paintCoin(cv, size, c))),
      ...engine.powerUps.map((p) => _Drawable(p.t, (c) => _paintPowerUp(c, size, p))),
    ]..sort((a, b) => a.t.compareTo(b.t));

    for (final _Drawable d in drawables) {
      d.paint(canvas);
    }

    if (engine.phase != Phase.menu) {
      _paintPlayer(canvas, size);
    }
    _paintParticles(canvas, size);
    _paintPopups(canvas, size);
  }

  // --- background ----------------------------------------------------
  void _paintSky(Canvas canvas, Size size, double horizonY) {
    final Rect sky = Rect.fromLTWH(0, 0, size.width, horizonY);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_skyTop, _skyBottom],
        ).createShader(sky),
    );

    // Sun.
    canvas.drawCircle(
      Offset(size.width * 0.78, horizonY * 0.4),
      size.width * 0.09,
      Paint()..color = _dashGold.withOpacity(0.9),
    );

    // Slow parallax clouds.
    final double drift = (engine.elapsed * 6) % (size.width + 160) - 80;
    final Paint cloud = Paint()..color = Colors.white.withOpacity(0.85);
    for (int i = 0; i < 4; i++) {
      final double cx = (drift + i * 190) % (size.width + 160) - 80;
      final double cy = horizonY * (0.25 + 0.15 * (i % 2));
      _paintCloud(canvas, Offset(cx, cy), 26 + 8 * (i % 3), cloud);
    }

    // Distant hills.
    final Path hills = Path()..moveTo(0, horizonY);
    const int segs = 6;
    for (int i = 0; i <= segs; i++) {
      final double x = size.width * i / segs;
      final double bump = math.sin(i * 1.3) * horizonY * 0.14;
      hills.lineTo(x, horizonY - horizonY * 0.16 - bump);
    }
    hills
      ..lineTo(size.width, horizonY)
      ..close();
    canvas.drawPath(hills, Paint()..color = _grassDark.withOpacity(0.55));
  }

  void _paintCloud(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c + Offset(r * 0.8, r * 0.15), r * 0.75, p);
    canvas.drawCircle(c + Offset(-r * 0.8, r * 0.2), r * 0.6, p);
  }

  void _paintGround(Canvas canvas, Size size, double horizonY) {
    final Rect ground = Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_grass, _grassDark],
        ).createShader(ground),
    );
  }

  void _paintRoad(Canvas canvas, Size size, double horizonY) {
    final double nearHalf = size.width * 0.60;
    final double farHalf = 18;
    final double cx = size.width / 2;
    final Path road = Path()
      ..moveTo(cx - farHalf, horizonY)
      ..lineTo(cx + farHalf, horizonY)
      ..lineTo(cx + nearHalf, size.height)
      ..lineTo(cx - nearHalf, size.height)
      ..close();
    canvas.drawPath(
      road,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[_road, _roadLight, _road],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(cx - nearHalf, horizonY, nearHalf * 2, size.height - horizonY)),
    );

    // Perspective tile seams (evenly spaced in `t`, matching the lane-dash
    // spacing model) for a sense of the road surface actually being made of
    // panels, rather than one flat slab.
    final Paint seam = Paint()
      ..color = Colors.black.withOpacity(0.14)
      ..strokeWidth = 1.4;
    const int seamCount = 7;
    for (int i = 1; i < seamCount; i++) {
      final double t = i / seamCount;
      final ({Offset pos, double scale, double halfW}) left = _project(size, -1, t);
      final ({Offset pos, double scale, double halfW}) right = _project(size, 1, t);
      canvas.drawLine(
        Offset(left.pos.dx - left.halfW * 0.05, left.pos.dy),
        Offset(right.pos.dx + right.halfW * 0.05, right.pos.dy),
        seam,
      );
    }

    // Glowing edge rails — a soft blurred underlay plus a bright core line,
    // teal on the left and gold on the right, echoing the reference strip.
    void edgeRail(double side, Color color) {
      final Path rail = Path()
        ..moveTo(cx + side * farHalf, horizonY)
        ..lineTo(cx + side * nearHalf, size.height);
      canvas.drawPath(
        rail,
        Paint()
          ..color = color.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        rail,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    edgeRail(-1, _dashTeal);
    edgeRail(1, _dashGold);

    // Scrolling lane-divider dashes at the two internal lane boundaries.
    final Paint dash = Paint()..color = _roadLine.withOpacity(0.85);
    const int dashCount = 9;
    final double phase = (engine.elapsed * (0.5 + engine.speed)) % 1.0;
    for (final double laneBoundary in <double>[-0.5, 0.5]) {
      for (int i = 0; i < dashCount; i++) {
        final double t = ((i / dashCount) + phase) % 1.0;
        final ({Offset pos, double scale, double halfW}) proj =
            _project(size, laneBoundary, t);
        final double w = 4 + 10 * proj.scale;
        final double h = 10 + 26 * proj.scale;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: proj.pos, width: w, height: h),
            Radius.circular(w * 0.3),
          ),
          dash,
        );
      }
    }

    // Road shoulders.
    final Paint shoulder = Paint()..color = _grassDark;
    canvas.drawPath(
      Path()
        ..moveTo(0, horizonY)
        ..lineTo(cx - farHalf, horizonY)
        ..lineTo(cx - nearHalf, size.height)
        ..lineTo(0, size.height)
        ..close(),
      shoulder,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width, horizonY)
        ..lineTo(cx + farHalf, horizonY)
        ..lineTo(cx + nearHalf, size.height)
        ..lineTo(size.width, size.height)
        ..close(),
      shoulder,
    );
  }

  // --- world objects ---------------------------------------------------
  void _paintObstacle(Canvas canvas, Size size, Obstacle o) {
    final ({Offset pos, double scale, double halfW}) proj = _project(size, o.lane.toDouble(), o.t);
    final bool tall = o.kind == ObstacleKind.barrier;
    final double w = (tall ? 46 : 42) * proj.scale;
    final double h = (tall ? 62 : 34) * proj.scale;
    final Rect box = Rect.fromCenter(
      center: proj.pos.translate(0, -h / 2),
      width: w,
      height: h,
    );
    final Color base = tall ? _barrierColor : _crateColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(w * 0.12)),
      Paint()..color = base,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.deflate(w * 0.12), Radius.circular(w * 0.1)),
      Paint()..color = base.withOpacity(0.55),
    );
    if (tall) {
      // Warning stripes.
      final Paint stripe = Paint()..color = Colors.white.withOpacity(0.85);
      for (int i = 0; i < 3; i++) {
        final double sy = box.top + box.height * (0.2 + i * 0.28);
        canvas.drawRect(Rect.fromLTWH(box.left, sy, box.width, box.height * 0.08), stripe);
      }
    }
    _paintShadow(canvas, proj.pos, w * 0.55);
  }

  void _paintCoin(Canvas canvas, Size size, Coin c) {
    final ({Offset pos, double scale, double halfW}) proj = _project(size, c.lane.toDouble(), c.t);
    final double r = 13 * proj.scale;
    final Offset center = proj.pos.translate(0, -r * 1.6);
    final double spin = math.sin(engine.elapsed * 9 + c.lane * 1.7 + c.t * 4);
    final double squish = 0.35 + 0.65 * spin.abs();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(squish, 1);
    canvas.drawCircle(Offset.zero, r, Paint()..color = _dashGold);
    canvas.drawCircle(Offset.zero, r * 0.62, Paint()..color = _dashGold.withOpacity(0.5));
    canvas.restore();
  }

  void _paintPowerUp(Canvas canvas, Size size, PowerUp p) {
    final ({Offset pos, double scale, double halfW}) proj = _project(size, p.lane.toDouble(), p.t);
    final double r = 17 * proj.scale;
    final Offset center = proj.pos.translate(0, -r * 1.8);
    final double pulse = 1 + 0.08 * math.sin(engine.elapsed * 7);
    final Color color = switch (p.kind) {
      PowerKind.magnet => _dashTeal,
      PowerKind.shield => const Color(0xFF5DA9F2),
      PowerKind.doubleScore => _dashGold,
    };
    canvas.drawCircle(center, r * pulse, Paint()..color = color.withOpacity(0.25));
    canvas.drawCircle(center, r * 0.62 * pulse, Paint()..color = color);
    final String glyph = switch (p.kind) {
      PowerKind.magnet => 'M',
      PowerKind.shield => 'S',
      PowerKind.doubleScore => '2×',
    };
    _drawCenteredText(canvas, glyph, center, r * 0.7, Colors.white);
  }

  void _paintShadow(Canvas canvas, Offset groundPos, double radius) {
    canvas.drawOval(
      Rect.fromCenter(center: groundPos, width: radius * 2, height: radius * 0.5),
      Paint()..color = Colors.black.withOpacity(0.22),
    );
  }

  // --- player ------------------------------------------------------------
  void _paintPlayer(Canvas canvas, Size size) {
    final ({Offset pos, double scale, double halfW}) proj =
        _project(size, engine.laneVisual, 1.0);
    final double jumpPx = engine.jumpHeight * 90;
    final Offset feet = proj.pos;
    _paintShadow(canvas, feet, 26 * (1 - engine.jumpHeight * 0.4));

    final ui.Image? sprite = engine.characterImage;
    if (sprite != null) {
      _paintPlayerSprite(canvas, sprite, feet, jumpPx);
    } else {
      _paintPlayerVector(canvas, feet, jumpPx);
    }

    if (engine.shieldActive) {
      canvas.drawCircle(
        feet.translate(0, -70 - jumpPx),
        50,
        Paint()
          ..color = _dashTeal.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  /// Draws the real character artwork. The source art is a back-view
  /// standing pose (no per-frame run cycle), so all the "alive" feeling
  /// here comes from whole-sprite transforms: a small vertical run-bob, a
  /// forward lean while airborne, and the existing jump arc/shadow.
  void _paintPlayerSprite(Canvas canvas, ui.Image img, Offset feet, double jumpPx) {
    const double baseHeight = 172;
    final double aspect = img.width / img.height;
    final double h = baseHeight;
    final double w = h * aspect;
    final double bob = engine.jumping ? 0.0 : math.sin(engine.elapsed * 14) * 3;
    final double lean = engine.jumping ? -0.11 : 0.0;
    final Offset topCenter = feet.translate(0, -jumpPx - h - bob);
    final Rect dst = Rect.fromLTWH(topCenter.dx - w / 2, topCenter.dy, w, h);
    final Rect src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    canvas.rotate(lean);
    canvas.translate(-dst.center.dx, -dst.center.dy);
    canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
  }

  /// Fallback used only if the sprite asset fails to load — keeps the game
  /// playable/visible rather than drawing nothing.
  void _paintPlayerVector(Canvas canvas, Offset feet, double jumpPx) {
    const double h = 74.0;
    final Offset body = feet.translate(0, -h / 2 - jumpPx);

    final double lean = engine.jumping ? -0.12 : 0.0;
    canvas.save();
    canvas.translate(body.dx, body.dy);
    canvas.rotate(lean);

    final Paint bodyPaint = Paint()..color = _dashTeal;
    final Paint bellyPaint = Paint()..color = const Color(0xFFFFF6E0);

    // Legs (simple running cycle when grounded).
    final double runPhase = engine.elapsed * 14;
    final double legSwing = engine.jumping ? 0.5 : math.sin(runPhase) * 0.55;
    final Paint legPaint = Paint()..color = const Color(0xFF2E7D74);
    for (final double side in <double>[-1, 1]) {
      final double swing = legSwing * side;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(10 * side, h * 0.34 + swing * 10),
            width: 12,
            height: 26,
          ),
          const Radius.circular(6),
        ),
        legPaint,
      );
    }

    // Body (egg-shaped torso).
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 46, height: 58),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 26, height: 34),
      bellyPaint,
    );

    // Head.
    canvas.drawCircle(const Offset(0, -34), 20, bodyPaint);
    canvas.drawCircle(const Offset(6, -38), 3.4, Paint()..color = Colors.black87);
    canvas.drawCircle(const Offset(-9, -34), 2.6, Paint()..color = Colors.black87);

    // Little quiff.
    final Path quiff = Path()
      ..moveTo(-4, -52)
      ..quadraticBezierTo(2, -66, 10, -50)
      ..quadraticBezierTo(0, -56, -4, -52)
      ..close();
    canvas.drawPath(quiff, Paint()..color = _dashGold);

    // Arms.
    final Paint armPaint = Paint()..color = _dashTeal;
    for (final double side in <double>[-1, 1]) {
      final double swing = -legSwing * side;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(22 * side, -6 + swing * 8),
            width: 10,
            height: 30,
          ),
          const Radius.circular(5),
        ),
        armPaint,
      );
    }

    canvas.restore();
  }

  // --- particles / popups ------------------------------------------------
  void _paintParticles(Canvas canvas, Size size) {
    for (final Particle p in engine.particles) {
      final ({Offset pos, double scale, double halfW}) proj =
          _project(size, p.anchorLane, 1.0);
      final Offset pos = proj.pos.translate(p.x, p.y - 40);
      final double alpha = (p.life / p.maxLife).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(pos, 4 * alpha + 1, Paint()..color = p.color.withOpacity(alpha));
    }
  }

  void _paintPopups(Canvas canvas, Size size) {
    for (final Popup p in engine.popups) {
      final ({Offset pos, double scale, double halfW}) proj =
          _project(size, p.anchorLane, 1.0);
      final Offset pos = proj.pos.translate(0, p.y - 70);
      final double alpha = (p.life / p.maxLife).clamp(0.0, 1.0).toDouble();
      _drawCenteredText(canvas, p.text, pos, 15, p.color.withOpacity(alpha), bold: true);
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    )
      ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize))
      ..addText(text);
    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 120));
    canvas.drawParagraph(paragraph, center.translate(-60, -fontSize / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

class _Drawable {
  _Drawable(this.t, this.paint);
  final double t;
  final void Function(Canvas canvas) paint;
}
