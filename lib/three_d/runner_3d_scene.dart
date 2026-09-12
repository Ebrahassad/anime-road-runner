import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart'
    as loaders;

class Runner3DScene extends StatefulWidget {
  const Runner3DScene({super.key});

  @override
  State<Runner3DScene> createState() => _Runner3DSceneState();
}

class _Runner3DSceneState extends State<Runner3DScene> {
  late three.ThreeJS threeJS;

  final three.Group playerGroup = three.Group();

  three.Mesh? leftLeg;
  three.Mesh? rightLeg;
  three.Mesh? leftArm;
  three.Mesh? rightArm;

  final List<three.Object3D> roadSegments = <three.Object3D>[];

  int currentLane = 0;

  double targetX = 0.0;

  static const double laneWidth = 2.0;

  bool isJumping = false;

  double verticalVelocity = 0.0;

  static const double gravity = -32.0;
  static const double jumpVelocity = 12.5;

  double animTime = 0.0;

  bool _roadLoading = false;

  @override
  void initState() {
    super.initState();

    threeJS = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) {
          setState(() {});
        }
      },
      setup: setupScene,
    );
  }

  @override
  void dispose() {
    threeJS.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // PROCEDURAL CHARACTER
  // -----------------------------------------------------------------------

  void createProceduralPlayer() {
    final hairMat = three.MeshStandardMaterial.fromMap({
      'color': 0xffaa00,
      'roughness': 0.3,
    });

    final skinMat = three.MeshStandardMaterial.fromMap({
      'color': 0xffccaa,
      'roughness': 0.6,
    });

    final jacketMat = three.MeshStandardMaterial.fromMap({
      'color': 0x1e88e5,
      'roughness': 0.3,
      'metalness': 0.1,
    });

    final innerMat = three.MeshStandardMaterial.fromMap({
      'color': 0xffffff,
      'roughness': 0.5,
    });

    final pantsMat = three.MeshStandardMaterial.fromMap({
      'color': 0x263238,
      'roughness': 0.5,
    });

    final shoeMat = three.MeshStandardMaterial.fromMap({
      'color': 0xe53935,
      'roughness': 0.2,
    });

    final visorMat = three.MeshStandardMaterial.fromMap({
      'color': 0x00e676,
      'roughness': 0.1,
      'metalness': 0.8,
    });

    // الرأس
    final head = three.Mesh(
      three.BoxGeometry(0.45, 0.45, 0.45),
      skinMat,
    );

    head.position.y = 1.5;
    playerGroup.add(head);

    // النظارة
    final visor = three.Mesh(
      three.BoxGeometry(0.48, 0.12, 0.25),
      visorMat,
    );

    visor.position.setValues(0, 1.53, 0.12);
    playerGroup.add(visor);

    // الشعر
    final hair = three.Mesh(
      three.ConeGeometry(0.35, 0.4, 5),
      hairMat,
    );

    hair.position.setValues(0, 1.8, 0);
    hair.rotation.x = 0.2;

    playerGroup.add(hair);

    // القميص
    final shirt = three.Mesh(
      three.BoxGeometry(0.4, 0.65, 0.25),
      innerMat,
    );

    shirt.position.y = 0.95;
    playerGroup.add(shirt);

    // السترة
    final jacket = three.Mesh(
      three.BoxGeometry(0.48, 0.68, 0.3),
      jacketMat,
    );

    jacket.position.y = 0.95;
    playerGroup.add(jacket);

    // الذراع اليسرى
    leftArm = three.Mesh(
      three.CylinderGeometry(0.07, 0.07, 0.5, 8),
      jacketMat,
    );

    leftArm!.position.setValues(-0.32, 0.95, 0);
    playerGroup.add(leftArm!);

    // الذراع اليمنى
    rightArm = three.Mesh(
      three.CylinderGeometry(0.07, 0.07, 0.5, 8),
      jacketMat,
    );

    rightArm!.position.setValues(0.32, 0.95, 0);
    playerGroup.add(rightArm!);

    // الساق اليسرى
    leftLeg = three.Mesh(
      three.CylinderGeometry(0.09, 0.08, 0.55, 8),
      pantsMat,
    );

    leftLeg!.position.setValues(-0.14, 0.35, 0);
    playerGroup.add(leftLeg!);

    // الساق اليمنى
    rightLeg = three.Mesh(
      three.CylinderGeometry(0.09, 0.08, 0.55, 8),
      pantsMat,
    );

    rightLeg!.position.setValues(0.14, 0.35, 0);
    playerGroup.add(rightLeg!);

    // الحذاء الأيسر
    final shoeLeft = three.Mesh(
      three.BoxGeometry(0.18, 0.14, 0.32),
      shoeMat,
    );

    shoeLeft.position.setValues(-0.14, 0.07, 0.05);
    playerGroup.add(shoeLeft);

    // الحذاء الأيمن
    final shoeRight = three.Mesh(
      three.BoxGeometry(0.18, 0.14, 0.32),
      shoeMat,
    );

    shoeRight.position.setValues(0.14, 0.07, 0.05);
    playerGroup.add(shoeRight);

    playerGroup.position.setValues(0, 0, 0);

    threeJS.scene.add(playerGroup);
  }

  // -----------------------------------------------------------------------
  // SCENE SETUP
  // -----------------------------------------------------------------------

  Future<void> setupScene() async {
    // مهم جدًا:
    // إنشاء Scene صراحةً قبل إضافة أي عنصر.
    threeJS.scene = three.Scene();

    threeJS.camera = three.PerspectiveCamera(
      60,
      threeJS.width / threeJS.height,
      0.1,
      1000,
    );

    threeJS.camera.position.setValues(
      0,
      3.2,
      -6.5,
    );

    // خلفية واضحة بدل الشاشة السوداء.
    threeJS.scene.background = three.Color(0x101522);

    // الإضاءة المحيطية.
    final ambient = three.AmbientLight(
      0xffffff,
      1.2,
    );

    threeJS.scene.add(ambient);

    // ضوء أمامي.
    final sun = three.DirectionalLight(
      0xffffff,
      1.8,
    );

    sun.position.setValues(
      5,
      15,
      -10,
    );

    threeJS.scene.add(sun);

    // ضوء إضافي خلفي لإظهار الشخصية.
    final fill = three.PointLight(
      0x4fd1c5,
      2.0,
      40,
    );

    fill.position.setValues(
      0,
      5,
      -5,
    );

    threeJS.scene.add(fill);

    threeJS.camera.lookAt(
      three.Vector3(
        0,
        1.2,
        5,
      ),
    );

    // الشخصية تُبنى فورًا.
    createProceduralPlayer();

    // لا ننتظر تحميل الطريق.
    // اللعبة تظهر أولًا ثم نحاول تحميل الطريق في الخلفية.
    unawaited(_loadRoad());

    // حلقة اللعبة.
    threeJS.addAnimationEvent((delta) {
      updateGame(delta);
    });
  }

  // -----------------------------------------------------------------------
  // ROAD
  // -----------------------------------------------------------------------

  Future<void> _loadRoad() async {
    if (_roadLoading) return;

    _roadLoading = true;

    try {
      final gltfLoader = loaders.GLTFLoader();

      final roadGltf = await gltfLoader.fromAsset(
        'assets/road-straight.glb',
      );

      if (!mounted || roadGltf?.scene == null) {
        return;
      }

      for (int i = 0; i < 6; i++) {
        final segment = roadGltf!.scene.clone(true);

        segment.position.z = i * 10.0;

        threeJS.scene.add(segment);

        roadSegments.add(segment);
      }
    } catch (e) {
      debugPrint(
        'Road loading failed: $e',
      );
    } finally {
      _roadLoading = false;
    }
  }

  // -----------------------------------------------------------------------
  // GAME LOOP
  // -----------------------------------------------------------------------

  void updateGame(double delta) {
    if (delta <= 0) return;

    final double dt = math.min(
      delta,
      0.05,
    );

    animTime += dt * 14.0;

    // حركة الركض.
    final double run = math.sin(animTime);

    leftLeg?.rotation.x = run * 0.65;
    rightLeg?.rotation.x = -run * 0.65;

    leftArm?.rotation.x = -run * 0.65;
    rightArm?.rotation.x = run * 0.65;

    // تحريك الطريق.
    for (final segment in roadSegments) {
      segment.position.z -= 16.0 * dt;

      if (segment.position.z < -10.0) {
        segment.position.z += 60.0;
      }
    }

    // انتقال اللاعب بين المسارات.
    final double difference = targetX - playerGroup.position.x;

    playerGroup.position.x += difference *
        math.min(
          1.0,
          16.0 * dt,
        );

    // القفز.
    if (isJumping) {
      playerGroup.position.y += verticalVelocity * dt;

      verticalVelocity += gravity * dt;

      if (playerGroup.position.y <= 0) {
        playerGroup.position.y = 0;
        verticalVelocity = 0;
        isJumping = false;
      }
    }
  }

  // -----------------------------------------------------------------------
  // INPUT
  // -----------------------------------------------------------------------

  void moveLane(int direction) {
    final int nextLane = (currentLane + direction).clamp(
      -1,
      1,
    );

    if (nextLane == currentLane) {
      return;
    }

    setState(() {
      currentLane = nextLane;
      targetX = currentLane * laneWidth;
    });
  }

  void jump() {
    if (isJumping) return;

    setState(() {
      isJumping = true;
      verticalVelocity = jumpVelocity;
    });
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (details) {
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
            }
          }
        },
        child: threeJS.build(),
      ),
    );
  }
}
