import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game/game_engine.dart';
import 'game/game_math.dart' as gm;
import 'game/game_painter.dart';
import 'l10n.dart';
import 'three_d/runner_3d_scene.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Catch-all so a stray error becomes a log line, never a fully blank
  // screen with no explanation.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  runApp(const RunnerApp());
}

const Color _bg = Color(0xFF0E1220);
const Color _gold = Color(0xFFFFC93C);
const Color _teal = Color(0xFF4FD1C5);
const Color _red = Color(0xFFE0533D);

class RunnerApp extends StatefulWidget {
  const RunnerApp({super.key});

  @override
  State<RunnerApp> createState() => _RunnerAppState();
}

class _RunnerAppState extends State<RunnerApp> {
  @override
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.language,
      builder: (context, lang, _) {
        return Directionality(
          textDirection: AppStrings.direction,
          child: MaterialApp(
            title: 'Anime Road Runner',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: _bg,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: _teal, brightness: Brightness.dark),
            ),
            home: const Runner3DScene(),
          ),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/icon/app_icon.png',
                  width: 84, height: 84),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: _teal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hosts the game loop (a [Ticker]), keyboard/swipe input, and every screen
/// the run passes through: menu -> playing -> crashed -> menu.
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.engine});
  final GameEngine engine;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _frame = 0;
  final FocusNode _focusNode = FocusNode();

  final TextEditingController _nameController = TextEditingController();
  bool _submittedThisRun = false;

  GameEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 1) return; // first frame / resumed-from-background
    engine.update(gm.clampDt(dt, 0.05));
    setState(() => _frame++);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startRun() {
    setState(() {
      _submittedThisRun = false;
      _nameController.clear();
      engine.startRun();
    });
  }

  void _backToMenu() {
    setState(() => engine.returnToMenu());
  }

  // --- input -------------------------------------------------------------
  Offset? _dragStart;

  void _onPanStart(DragStartDetails d) => _dragStart = d.globalPosition;

  void _onPanEnd(DragEndDetails d) {
    final Offset? start = _dragStart;
    _dragStart = null;
    if (start == null) return;
    // DragEndDetails has no position; use velocity direction as the swipe
    // heuristic together with the primary-velocity magnitude threshold.
    final Offset v = d.velocity.pixelsPerSecond;
    if (v.distance < 200) {
      if (engine.phase == Phase.menu) _startRun();
      return;
    }
    if (v.dx.abs() > v.dy.abs()) {
      if (v.dx < 0) {
        engine.moveLeft();
      } else {
        engine.moveRight();
      }
    } else {
      if (v.dy < 0) {
        engine.jump();
      }
    }
  }

  void _onTap() {
    if (engine.phase == Phase.menu) _startRun();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = event.logicalKey;
    if (engine.phase == Phase.menu) {
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
        _startRun();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (engine.phase == Phase.crashed) {
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
        _startRun();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyM) {
        _backToMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      engine.moveLeft();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      engine.moveRight();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW ||
        k == LogicalKeyboardKey.space) {
      engine.jump();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanEnd: _onPanEnd,
          onTap: _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: GamePainter(engine, _frame),
                child: const SizedBox.expand(),
              ),
              if (engine.phase == Phase.playing) _Hud(engine: engine),
              if (engine.phase == Phase.menu)
                _MenuOverlay(engine: engine, onPlay: _startRun),
              if (engine.phase == Phase.crashed)
                _GameOverOverlay(
                  engine: engine,
                  nameController: _nameController,
                  submitted: _submittedThisRun,
                  onSubmit: () async {
                    await engine.submitScore(_nameController.text);
                    setState(() => _submittedThisRun = true);
                  },
                  onPlayAgain: _startRun,
                  onMenu: _backToMenu,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HUD --------------------------------------------------------------

class _Hud extends StatelessWidget {
  const _Hud({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Capsule(child: Text('${engine.score}', style: _hudScoreStyle)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (engine.shieldActive) _badge('🛡', _teal),
                if (engine.magnetTimeLeft > 0) _badge('🧲', _teal),
                if (engine.doubleScoreTimeLeft > 0) _badge('×2', _gold),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _Capsule(
          color: color.withOpacity(0.85),
          child: Text(text,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      );
}

const TextStyle _hudScoreStyle =
    TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800);

class _Capsule extends StatelessWidget {
  const _Capsule({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

// --- Menu ----------------------------------------------------------------

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({required this.engine, required this.onPlay});
  final GameEngine engine;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              AppStrings.t('app_name'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.t('tagline'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    AppStrings.t('best_scores'),
                    style: const TextStyle(
                        color: _teal, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (engine.leaderboard.isEmpty)
                    Text(
                      AppStrings.t('no_scores'),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    )
                  else
                    ...List<Widget>.generate(engine.leaderboard.length, (i) {
                      final entry = engine.leaderboard[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('${i + 1}. ${entry.name}',
                                style: const TextStyle(color: Colors.white70)),
                            Text('${entry.score}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: _bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  AppStrings.t('play'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.t('tap_to_play'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openSettings(context, engine),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              icon: const Icon(Icons.settings, size: 18),
              label: Text(AppStrings.t('settings')),
            ),
          ],
        ),
      ),
    );
  }
}

void _openSettings(BuildContext context, GameEngine engine) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF161B2C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SettingsSheet(engine: engine),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.engine});
  final GameEngine engine;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final GameEngine engine = widget.engine;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              AppStrings.t('settings'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(AppStrings.t('language'),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SegButton(
                    label: 'English',
                    selected: AppStrings.language.value == AppLanguage.en,
                    onTap: () =>
                        setState(() => engine.setLanguage(AppLanguage.en)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegButton(
                    label: 'العربية',
                    selected: AppStrings.language.value == AppLanguage.ar,
                    onTap: () =>
                        setState(() => engine.setLanguage(AppLanguage.ar)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(AppStrings.t('sound_effects'),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (int i = 0; i < kVolumes.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i == kVolumes.length - 1 ? 0 : 8),
                      child: _SegButton(
                        label: AppStrings.t(<String>['off', 'low', 'high'][i]),
                        selected: engine.volumeIndex == i,
                        onTap: () => setState(() => engine.setVolumeIndex(i)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppStrings.t('close')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _bg : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// --- Game over -------------------------------------------------------

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.engine,
    required this.nameController,
    required this.submitted,
    required this.onSubmit,
    required this.onPlayAgain,
    required this.onMenu,
  });

  final GameEngine engine;
  final TextEditingController nameController;
  final bool submitted;
  final VoidCallback onSubmit;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final bool showNameEntry = engine.isNewBest && !submitted;
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF161B2C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    AppStrings.t('crashed'),
                    style: const TextStyle(
                        color: _red, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.t('score_best_line')
                        .replaceFirst('%s', '${engine.score}')
                        .replaceFirst('%s', '${engine.bestScore}'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (engine.isNewBest) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.t(submitted ? 'new_best_bang' : 'new_best'),
                      style: const TextStyle(
                          color: _gold, fontWeight: FontWeight.w800),
                    ),
                  ],
                  if (showNameEntry) ...<Widget>[
                    const SizedBox(height: 14),
                    Text(AppStrings.t('enter_name'),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      autofocus: false,
                      maxLength: 12,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: AppStrings.t('name_hint'),
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _bg,
                        ),
                        child: Text(AppStrings.t('save'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onPlayAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: _bg,
                          ),
                          child: Text(AppStrings.t('play_again'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onMenu,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70),
                          child: Text(AppStrings.t('menu')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Anime Road Runner — score ${engine.score}!',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Copied!'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                    icon: const Icon(Icons.share,
                        size: 16, color: Colors.white54),
                    label: Text(
                      AppStrings.t('share_score'),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Text(
                    AppStrings.t('hint_keys'),
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
