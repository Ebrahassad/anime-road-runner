import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart'
    as loaders;

/// Isolated 3D runner scene.
///
/// The existing 2D game remains untouched. This scene is deliberately
/// separated so the 3D migration can be introduced incrementally.
class Runner3DScene extends StatefulWidget {
  const Runner3DScene({super.key});

  @override
  State<Runner3DScene> createState() => _Runner3DSceneState();
}

class _Runner3DSceneState extends State<Runner3DScene> {
  late final three.ThreeJS threeJS;

  three.Object3D? player;
  three.AnimationMixer? mixer;

  final Map<String, three.AnimationAction> actions =
      <String, three.AnimationAction>{};

  three.AnimationAction? activeAction;

  final List<three.Object3D> roadSegments = <three.Object3D>[];

  int currentLane = 0;

  double targetX = 0;
  double laneWidth = 2;

  double gameSpeed = 15;
  double segmentLength = 10;

  bool isJumping = false;
  bool isSliding = false;

  double verticalVelocity = 0;
  double gravity = -30;

  static const int _segmentCount = 6;

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

  Future<void> _setupScene() async {
    threeJS.camera = three.PerspectiveCamera(
      60,
      threeJS.width / threeJS.height,
      0.1,
      1000,
    );

    threeJS.camera.position.setValues(
      0,
      3,
      -6,
    );

    threeJS.camera.lookAt(
      three.Vector3(0, 1, 5),
    );

    threeJS.scene.add(
      three.AmbientLight(
        0xffffff,
        0.8,
      ),
    );

    final three.DirectionalLight sun = three.DirectionalLight(
      0xfffaed,
      1.5,
    );

    sun.position.setValues(
      5,
      15,
      -10,
    );

    sun.castShadow = true;

    threeJS.scene.add(sun);

    threeJS.scene.fog = three.FogExp2(
      0x1a1a24,
      0.015,
    );

    final loaders.GLTFLoader loader = loaders.GLTFLoader();

    await _loadRoad(loader);
    await _loadPlayer(loader);

    threeJS.addAnimationEvent(
      _updateGame,
    );
  }

  Future<void> _loadRoad(
    loaders.GLTFLoader loader,
  ) async {
    try {
      final dynamic gltf = await loader.fromAsset('assets/road-straight.glb');

      if (gltf == null || gltf.scene == null) {
        return;
      }

      final three.Object3D baseRoad = gltf.scene!;

      baseRoad.traverse(
        (three.Object3D child) {
          if (child is three.Mesh) {
            child.receiveShadow = true;
          }
        },
      );

      for (int i = 0; i < _segmentCount; i++) {
        final three.Object3D segment = baseRoad.clone(true);

        segment.position.z = i * segmentLength;

        threeJS.scene.add(segment);
        roadSegments.add(segment);
      }
    } catch (error) {
      debugPrint(
        '3D road loading error: $error',
      );
    }
  }

  Future<void> _loadPlayer(
    loaders.GLTFLoader loader,
  ) async {
    try {
      final dynamic gltf = await loader.fromAsset('assets/dash.glb');

      if (gltf == null || gltf.scene == null) {
        return;
      }

      player = gltf.scene!;

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

      mixer = three.AnimationMixer(
        player!,
      );

      if (gltf.animations != null) {
        for (final dynamic clip in gltf.animations!) {
          final three.AnimationAction? action = mixer!.clipAction(clip);

          if (action != null) {
            actions[clip.name] = action;
          }
        }
      }

      _switchAnimation('Running');
    } catch (error) {
      debugPrint(
        '3D player loading error: $error',
      );
    }
  }

  void _switchAnimation(
    String name,
  ) {
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

  void _updateGame(
    double delta,
  ) {
    mixer?.update(delta);

    for (final three.Object3D segment in roadSegments) {
      segment.position.z -= gameSpeed * delta;

      if (segment.position.z < -segmentLength) {
        segment.position.z += _segmentCount * segmentLength;
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

  void moveLane(
    int direction,
  ) {
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
      verticalVelocity = 12;

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

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onPanEnd: (
        DragEndDetails details,
      ) {
        final double dx = details.velocity.pixelsPerSecond.dx;

        final double dy = details.velocity.pixelsPerSecond.dy;

        if (dx.abs() > dy.abs()) {
          if (dx > 200) {
            moveLane(1);
          } else if (dx < -200) {
            moveLane(-1);
          }
        } else if (dy < -200) {
          jump();
        } else if (dy > 200) {
          slide();
        }
      },
      child: ColoredBox(
        color: Colors.black,
        child: threeJS.build(),
      ),
    );
  }
}
