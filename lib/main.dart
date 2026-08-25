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

const Color _bootBg = Color(0xFF0E1220);
const Color _bootGold = Color(0xFFFFC93C);
const Color _bootTeal = Color(0xFF4FD1C5);
const Color _bootRed = Color(0xFFE0533D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Do not perform GPU/Scene initialization before runApp().
  // The Flutter UI must get its first frame first.
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
      builder: (
        BuildContext context,
        AppLanguage lang,
        Widget? child,
      ) {
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

/// Starts flutter_scene / Flutter GPU only after the first Flutter frame.
///
/// There is intentionally NO artificial timeout here. The previous 20-second
/// timeout converted a slow/hanging GPU initialization into a misleading
/// "Could not start the 3D engine" error.
///
/// The boot screen remains visible and its timer continues running while the
/// Scene initialization Future is pending.
class _EngineGate extends StatefulWidget {
  const _EngineGate();

  @override
  State<_EngineGate> createState() => _EngineGateState();
}

class _EngineGateState extends State<_EngineGate> {
  Future<void>? _ready;
  bool _initializationStarted = false;

  @override
  void initState() {
    super.initState();

    // Let Flutter paint the boot screen first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initializationStarted) {
        return;
      }

      _initializationStarted = true;

      setState(() {
        _startInit();
      });
    });
  }

  void _startInit() {
    debugPrint(
      '[EngineGate] Starting Scene.initializeStaticResources()...',
    );

    try {
      late final Future<void> initializationFuture;

      // Protect synchronous exceptions as well.
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

        _ready = Future<void>.error(
          error,
          stackTrace,
        );
        return;
      }

      // IMPORTANT:
      // No timeout here.
      //
      // If the GPU initialization takes a long time, the boot screen remains
      // alive and the elapsed-time counter continues to show that Flutter
      // itself is still running.
      _ready = initializationFuture;

      debugPrint(
        '[EngineGate] Initialization Future is being monitored.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[EngineGate] UNEXPECTED initialization error: $error',
      );
      debugPrint(
        '[EngineGate] Stack trace:\n$stackTrace',
      );

      _ready = Future<void>.error(
        error,
        stackTrace,
      );
    }
  }

  void _retry() {
    if (!mounted) {
      return;
    }

    debugPrint(
      '[EngineGate] Retrying engine initialization...',
    );

    setState(() {
      _ready = null;
      _initializationStarted = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initializationStarted) {
        return;
      }

      _initializationStarted = true;

      setState(() {
        _startInit();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready == null) {
      return const _BootScreen();
    }

    return FutureBuilder<void>(
      future: _ready,
      builder: (
        BuildContext context,
        AsyncSnapshot<void> snapshot,
      ) {
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

/// Boot screen shown while the GPU/Scene pipeline initializes.
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
          setState(() {
            _seconds = _stopwatch.elapsed.inSeconds;
          });
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

/// Error screen shown only when initialization actually throws.
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