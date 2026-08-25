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
      if (mounted) setState(_startInit);
    });
  }

  void _startInit() {
    _ready = Scene.initializeStaticResources().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(
          'Timed out waiting for the GPU shader pipeline to initialize.'),
    );
  }

  void _retry() {
    setState(_startInit);
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
          return _BootErrorScreen(
            error: snapshot.error,
            onRetry: _retry,
          );
        }
        return const GamePage();
      },
    );
  }
}

/// Shown for the brief window while GPU shader resources compile. Replaces
/// the native launch screen almost instantly, then this replaces itself with
/// the game once ready — so the person always sees *something* moving.
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bootBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_bootTeal),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t('app_name'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only if GPU/shader initialization genuinely fails (e.g. a device or
/// build without Flutter GPU enabled). This is the safe alternative to the
/// previous behaviour, where the same failure threw before `runApp` and left
/// the OS splash screen on screen forever with no feedback at all.
class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.error, required this.onRetry});

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
                const Icon(Icons.error_outline_rounded,
                    color: _bootRed, size: 44),
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
                  'Your device or build may not have Flutter GPU enabled.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bootGold,
                    foregroundColor: _bootBg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('RETRY',
                      style: TextStyle(fontWeight: FontWeight.w800)),
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