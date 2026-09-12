import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart'
    as loaders;

/// Isolated 3D runner scene.
///
/// Loads the road and character itself and shows an explicit loading status.
/// This prevents the old GameEngine initialization from blocking the 3D game.
class Runner3DScene extends StatefulWidget {
  const Runner3DScene({super.key});

  @override
  State<Runner3DScene> createState() => _Runner3DSceneState();
}

class _Runner3DSceneState extends State<Runner3DScene> {
  late final three.ThreeJS threeJS;

  three.AnimationMixer? mixer;
  final Map<String, three.AnimationAction> actions =
      <String, three.AnimationAction>{};
  three.AnimationAction? activeAction;
  three.Object3D? player;

  final List<three.Object3D> roadSegments = <three.Object3D>[];

  int currentLane = 0;
  double targetX = 0.0;
  double laneWidth = 2.0;

  bool isJumping = false;
  bool isSliding = false;
  double verticalVelocity = 0.0;
  double gravity = -30.0;

  static const double segmentLength = 10.0;
  static const int numSegments = 6;
  static const double gameSpeed = 15.0;

  bool isLoading = true;
  String statusMessage = 'جاري تهيئة المحرك...';
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    threeJS = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) {
          setState(() {});
        }
      },
      setup: _setupScene,
    );
  }

  @override
  void dispose() {
    threeJS.dispose();
    super.dispose();
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = message;
    });
  }

  Future<void> _setupScene() async {
    try {
      _setStatus('جاري تهيئة المشهد...');

      threeJS.camera = three.PerspectiveCamera(
        60,
        threeJS.width / threeJS.height,
        0.1,
        1000,
      );

      threeJS.camera.position.setValues(0, 3, -6);
      threeJS.camera.lookAt(
        three.Vector3(0, 1, 5),
      );

      threeJS.scene.add(
        three.AmbientLight(
          0xffffff,
          0.8,
        ),
      );

      final three.DirectionalLight sun = three.DirectionalLight(0xfffaed, 1.5);

      sun.position.setValues(5, 15, -10);
      sun.castShadow = true;
      threeJS.scene.add(sun);

      threeJS.scene.fog = three.FogExp2(
        0x1a1a24,
        0.015,
      );

      final loaders.GLTFLoader loader = loaders.GLTFLoader();

      // ---------------------------------------------------------------
      // Road
      // ---------------------------------------------------------------
      _setStatus('جاري تحميل الطريق...');

      debugPrint('3D: Starting road load...');

      final dynamic roadGltf =
          await loader.fromAsset('assets/road-straight.glb');

      if (roadGltf != null && roadGltf.scene != null) {
        final three.Object3D baseRoad = roadGltf.scene!;

        baseRoad.traverse(
          (three.Object3D child) {
            if (child is three.Mesh) {
              child.receiveShadow = true;
            }
          },
        );

        for (int i = 0; i < numSegments; i++) {
          final three.Object3D segment = baseRoad.clone(true);

          segment.position.z = i * segmentLength;

          threeJS.scene.add(segment);
          roadSegments.add(segment);
        }

        debugPrint('3D: Road loaded successfully.');
      } else {
        debugPrint('3D: Road asset returned no scene.');
      }

      // ---------------------------------------------------------------
      // Character
      // ---------------------------------------------------------------
      _setStatus('جاري معالجة مجسم الشخصية...');

      debugPrint('3D: Starting character load...');

      final dynamic dashGltf = await loader.fromAsset('assets/dash.glb');

      if (dashGltf != null && dashGltf.scene != null) {
        player = dashGltf.scene!;

        player!.position.setValues(
          0,
          0,
          0,
        );

        player!.traverse(
          (three.Object3D child) {
            if (child is three.Mesh) {
              child.castShadow = true;
            }
          },
        );

        threeJS.scene.add(player!);

        mixer = three.AnimationMixer(player!);

        if (dashGltf.animations != null) {
          for (final dynamic clip in dashGltf.animations!) {
            final three.AnimationAction? action = mixer!.clipAction(clip);

            if (action != null) {
              actions[clip.name] = action;
            }
          }
        }

        _switchAnimation('Running');

        debugPrint('3D: Character loaded successfully.');
      } else {
        debugPrint('3D: Character asset returned no scene.');
      }

      // ---------------------------------------------------------------
      // Game loop
      // ---------------------------------------------------------------
      threeJS.addAnimationEvent(_updateGame);

      if (mounted) {
        setState(() {
          isLoading = false;
          statusMessage = 'جاهز!';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('3D SETUP ERROR: $error');
      debugPrint('3D STACKTRACE: $stackTrace');

      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
          statusMessage = 'حدث خطأ أثناء تحميل اللعبة';
        });
      }
    }
  }

  void _switchAnimation(String name) {
    final three.AnimationAction? next = actions[name];

    if (next == null || next == activeAction) {
      return;
    }

    activeAction?.fadeOut(0.15);

    next.reset();
    next.fadeIn(0.15);
    next.play();

    activeAction = next;
  }

  void _updateGame(double delta) {
    mixer?.update(delta);

    for (final three.Object3D segment in roadSegments) {
      segment.position.z -= gameSpeed * delta;

      if (segment.position.z < -segmentLength) {
        segment.position.z += numSegments * segmentLength;
      }
    }

    final three.Object3D? currentPlayer = player;

    if (currentPlayer == null) {
      return;
    }

    currentPlayer.position.x +=
        (targetX - currentPlayer.position.x) * 15 * delta;

    if (!isJumping) {
      return;
    }

    currentPlayer.position.y += verticalVelocity * delta;
    verticalVelocity += gravity * delta;

    if (currentPlayer.position.y <= 0) {
      currentPlayer.position.y = 0;
      verticalVelocity = 0;
      isJumping = false;
      _switchAnimation('Running');
    }
  }

  void moveLane(int direction) {
    setState(() {
      currentLane = (currentLane + direction).clamp(-1, 1);
      targetX = currentLane * laneWidth;
    });
  }

  void jump() {
    if (isJumping || isSliding) {
      return;
    }

    setState(() {
      isJumping = true;
      verticalVelocity = 12.0;
      _switchAnimation('Jump');
    });
  }

  void slide() {
    if (isJumping || isSliding) {
      return;
    }

    setState(() {
      isSliding = true;
      _switchAnimation('Slide');
    });

    Future<void>.delayed(
      const Duration(milliseconds: 800),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          isSliding = false;
          _switchAnimation('Running');
        });
      },
    );
  }

  void _handleSwipe(DragEndDetails details) {
    final double dx = details.velocity.pixelsPerSecond.dx;
    final double dy = details.velocity.pixelsPerSecond.dy;

    if (dx.abs() > dy.abs()) {
      if (dx > 200) {
        moveLane(1);
      } else if (dx < -200) {
        moveLane(-1);
      }
    } else {
      if (dy < -200) {
        jump();
      } else if (dy > 200) {
        slide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: _handleSwipe,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: Colors.black,
              child: threeJS.build(),
            ),
            if (isLoading)
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (errorMessage != null)
              ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
