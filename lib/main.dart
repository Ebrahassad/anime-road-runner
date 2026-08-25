import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_bench.dart' as bench;
import 'game_math.dart' as gm;
import 'game_textures.dart' as gt;
import 'l10n.dart';

part 'game_state.dart';
part 'game_painter.dart';
part 'models.dart';

// --- App palette used before the game world exists -------------------------
// (boot / error screens run before `_GamePageState`'s own palette exists, so
// they carry their own tiny copy rather than reaching into the game state).
const Color _bootBg = Color(0xFF0E1220);
const Color _bootGold = Color(0xFFFFC93C);
const Color _bootTeal = Color(0xFF4FD1C5);
const Color _bootRed = Color(0xFFE0533D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: `runApp` is called immediately, with no awaited work before
  // it. Flutter's native launch screen (Android `launch_background.xml` /
  // macOS launch storyboard) stays on screen only until the FIRST Flutter
  // frame is painted. Anything awaited here — GPU shader compilation, asset
  // loading, etc. — delays that first frame and, if it throws or hangs, the
  // app never leaves the splash screen at all. All heavy startup work
  // (`Scene.initializeStaticResources()`, world/model loading) now happens
  // *after* the first frame, inside `_EngineGate`/`_GamePageState`, each
  // guarded by its own error handling so a failure shows a message instead
  // of a frozen screen.
  runApp(const RunnerApp());
}

enum Phase {
  menu,
  playing,
  crashed,
}

enum PowerKind {
  magnet,
  shield,
  doubleScore,
}

class RunnerApp extends StatelessWidget {
  const RunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.language,
      builder: (BuildContext context, AppLanguage lang, Widget? child) {
        return Directionality(
          textDirection: AppStrings.direction,
          child: MaterialApp(
            title: 'Anime Road Runner',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: _bootBg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: _bootTeal,
                brightness: Brightness.dark,
              ),
            ),
            home: const _EngineGate(),
          ),
        );
      },
    );
  }
}

/// Boots the `flutter_scene` / Flutter GPU shader pipeline strictly *after*
/// the first Flutter frame is already on screen, and never lets a startup
/// failure freeze the app: success moves on to [GamePage], failure shows a
/// friendly, retryable error screen instead of an unrecoverable hang.
class _EngineGate extends StatefulWidget {
  const _EngineGate();

  @override
  State<_EngineGate> createState() => _EngineGateState();
}

class _EngineGateState extends State<_EngineGate> {
  // Deliberately null until after the FIRST Flutter frame has actually been
  // painted. `initState()` runs during the BUILD phase of that same first
  // frame -- calling Scene.initializeStaticResources() from here (even
  // "after runApp()" in main.dart) still blocks frame 1 if the call does any
  // synchronous native/shader work before its first internal `await`. That
  // is exactly what kept happening: the launch screen ended, but the very
  // next Flutter frame never painted either, so the OS fell back to its
  // plain grey NormalTheme window background and sat there indefinitely.
  // Starting the engine from a post-frame callback instead guarantees frame
  // 1 (this boot screen) is fully on screen *before* that work begins.
  Future<void>? _ready;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(_startInit);
      }
    });
  }

  /// Starts the scene initialization safely.
  ///
  /// IMPORTANT:
  /// Scene.initializeStaticResources() itself is inside try/catch because
  /// it may theoretically throw synchronously before returning a Future.
  /// In that case `.timeout()` cannot protect the call because no Future
  /// exists yet.
  void _startInit() {
    debugPrint(
      '[EngineGate] Starting Scene.initializeStaticResources()...',
    );

    try {
      late final Future<void> initializationFuture;

      // Protect the CALL itself.
      try {
        initializationFuture = Scene.initializeStaticResources();

        debugPrint(
          '[EngineGate] Scene.initializeStaticResources() returned a Future.',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[EngineGate] SYNCHRONOUS initialization error: $error',
        );
        debugPrint(
          '[EngineGate] Stack trace:\n$stackTrace',
        );

        // Convert the synchronous exception into a Future error so
        // FutureBuilder can display the error screen normally.
        _ready = Future<void>.error(error, stackTrace);
        return;
      }

      // The Future now definitely exists, therefore timeout() is safe.
      _ready = initializationFuture.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          final TimeoutException timeout = TimeoutException(
            'Timed out waiting for the GPU shader pipeline to initialize.',
            const Duration(seconds: 20),
          );

          debugPrint(
            '[EngineGate] INITIALIZATION TIMEOUT: $timeout',
          );

          throw timeout;
        },
      );

      debugPrint(
        '[EngineGate] Initialization Future is now being monitored.',
      );
    } catch (error, stackTrace) {
      // Defensive outer catch. This prevents _ready from remaining null if
      // something unexpected escapes the initialization setup.
      debugPrint(
        '[EngineGate] UNEXPECTED initialization error: $error',
      );
      debugPrint(
        '[EngineGate] Stack trace:\n$stackTrace',
      );

      _ready = Future<void>.error(error, stackTrace);
    }
  }

  void _retry() {
    if (!mounted) {
      return;
    }

    debugPrint('[EngineGate] Retrying engine initialization...');

    setState(() {
      // Reset the old Future before starting the new attempt.
      _ready = null;

      _startInit();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready == null) {
      // First frame: nothing has been asked of the GPU/shader pipeline yet.
      return const _BootScreen();
    }

    return FutureBuilder<void>(
      future: _ready,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootScreen();
        }

        if (snapshot.hasError) {
          debugPrint(
            '[EngineGate] Initialization failed: ${snapshot.error}',
          );

          if (snapshot.stackTrace != null) {
            debugPrint(
              '[EngineGate] Initialization stack trace:\n'
              '${snapshot.stackTrace}',
            );
          }

          return _BootErrorScreen(
            error: snapshot.error,
            onRetry: _retry,
          );
        }

        debugPrint(
          '[EngineGate] Engine initialization completed successfully.',
        );

        return const GamePage();
      },
    );
  }
}

/// Shown for the brief window while GPU shader resources compile. Replaces
/// the native launch screen almost instantly, then this replaces itself with
/// the game once ready — so the person always sees *something* moving.
///
/// Deliberately shows a live elapsed-time counter rather than a fake
/// percentage bar: `Scene.initializeStaticResources()` gives no progress
/// callbacks, so a "filling" progress bar would just be a lie. The counter
/// (and the indeterminate bar still animating) is also a genuine diagnostic:
/// if the whole engine truly locks up at the native/GPU-driver level, BOTH
/// stop moving at once — which is exactly what to look for and report back.
class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  final Stopwatch _stopwatch = Stopwatch()..start();

  Timer? _timer;

  int _seconds = 0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(
            () => _seconds = _stopwatch.elapsed.inSeconds,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? hint = _seconds >= 12
        ? AppStrings.t('boot_taking_long')
        : _seconds >= 5
            ? AppStrings.t('boot_still_working')
            : null;

    return Scaffold(
      backgroundColor: _bootBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                AppStrings.t('app_name'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 26),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  width: 180,
                  height: 5,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0x22FFFFFF),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _bootTeal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${AppStrings.t('boot_initializing')}  ·  ${_seconds}s',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              if (hint != null) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown only if GPU/shader initialization genuinely fails (e.g. a device or
/// build without Flutter GPU enabled). This is the safe alternative to the
/// previous behaviour, where the same failure threw before `runApp` and left
/// the OS splash screen on screen forever with no feedback.
class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({
    required this.error,
    required this.onRetry,
  });

  final Object? error;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bootBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  color: _bootRed,
                  size: 44,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Could not start the 3D engine',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error == null
                      ? 'Your device or build may not have Flutter GPU enabled.'
                      : 'Initialization failed:\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bootGold,
                    foregroundColor: _bootBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'RETRY',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}