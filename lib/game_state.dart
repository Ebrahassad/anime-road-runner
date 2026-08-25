part of 'main.dart';

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  static const double roadWidth = 6.0;
  static const double laneWidth = 2.0;
  static const double segLen = 3.5;
  static const int tileCount = 24;
  static const double totalLen = tileCount * segLen;
  static const double zFar = -62.0;
  static const double roadTopY = -0.9;
  static const double groundY = roadTopY + 0.5;
  static const double runnerZ = 1.5;
  static const double runnerHalf = 0.5;

  static const String dashAsset = 'assets/models/dash.glb';
  static const double dashScale = 0.5;
  static const double dashYaw = math.pi;
  static const double dashFootY = roadTopY;
  static const double dashTurnGain = 5.0;
  static const double dashTurnMax = 0.45;
  static const double dashAnimBlend = 16.0;

  static const double camY = 2.9;
  static const double camZ = 11.0;
  static const double camTargetY = -0.85;
  static const double camTargetZ = -16.0;

  static const double baseSpeed = 15.0;
  static const double maxSpeed = 32.0;
  static const double speedRampPerSec = 0.45;
  static const double laneLerp = 12.0;
  static const double maxFrameDt = 0.05;
  static const double gravity = 52.0;
  static const double jumpImpulse = 9.1;

  static const int obstacleCount = 10;
  static const double obHalfX = 0.6;
  static const double obHalfY = 0.5;
  static const double obHalfZ = 0.5;
  static const double obstacleCenterY = groundY;
  static const double obSpacing = 17.0;
  static const double firstSpawnDelay = 1.6;
  static const double wallChance = 0.35;
  static const double wallAfter = 8.0;

  static const int coinCount = 36;
  static const double coinY = groundY + 0.35;
  static const int coinsPerLine = 6;
  static const double coinGap = 2.5;
  static const double coinRadius = 0.36;
  static const double coinArcH = 0.85;
  static const double coinInterval = 1.7;
  static const int coinScore = 25;

  static const double spawnZ = -58.0;
  static const double despawnZ = 8.0;

  static const int postCount = 9;
  static const double postSpacing = totalLen / postCount;
  static const int dashCount = 18;
  static const double dashSpacing = totalLen / dashCount;

  static const Color cTeal = Color(0xFF4FD1C5);
  static const Color cGold = Color(0xFFFFC93C);
  static const Color cRed = Color(0xFFE0533D);
  static const int cCoin = 0xFFFFD54A;
  static const int cCrash = 0xFFE0533D;
  static const Color cBg = Color(0xFF0E1220);

  static const List<int> particleColors = <int>[
    cCoin,
    cCrash,
    cMagnet,
    cShield,
    cDouble,
  ];
  static const int particlesPerColor = 24;
  static const double particleGravity = 16.0;
  static const double shakeDuration = 0.4;

  static const double coinGlow = 2.0;
  static const double postGlow = 2.2;
  static const double obstacleGlow = 1.6;
  static const double particleGlow = 2.0;
  static const double bloomThreshold = 1.0;
  static const double bloomIntensity = 0.55;
  static const double bloomScatter = 0.75;
  static const double vignetteIntensity = 0.34;
  static const int fogHex = 0xFF131A30;
  static const double fogStart = 34.0;
  static const double fogEnd = 62.0;

  static const int cSkyTop = 0xFF4B9BE8;
  static const int cSkyBot = 0xFFDCEEFF;
  static const int cGrass = 0xFF43883D;
  static const int cAsphaltA = 0xFF30343B;
  static const int cAsphaltB = 0xFF3A4048;
  static const int cHedge = 0xFF3F9B4F;
  static const double groundHalfW = 40.0;
  static const double groundLen = 280.0;
  static const int shadowCascades = 1;
  static const int shadowMapRes = 2048;
  static const double shadowDistance = 24.0;

  static const List<double> qualityScales = <double>[1.0, 0.85, 0.65];

  static const List<double> qualityDensity = <double>[1.0, 0.55, 0.3];

  static const double pixelBudget = 1100000.0;

  static const double minRenderScale = 0.35;
  static const List<String> qualityNames = <String>['HIGH', 'BALANCED', 'FAST'];

  static const double sunIntensity = 2.35;
  static const double envIntensity = 1.75;
  static const int cFogDay = 0xFFCDEBFF;
  static const double fogStartDay = 40.0;
  static const double fogEndDay = 80.0;
  static const int cTrunk = 0xFF7A5233;
  static const double trunkH = 0.7;
  static const List<List<double>> _pineTierDims = <List<double>>[
    <double>[0.82, 1.2],
    <double>[0.6, 0.95],
    <double>[0.4, 0.72],
  ];
  static const List<double> _roundBlobRadii = <double>[0.64, 0.42, 0.40];
  static const int cPine = 0xFF2F7D44;
  static const int cLeaf = 0xFF5CB248;
  static const double treeX = roadWidth / 2 + 2.3;
  static const int houseCount = 5;
  static const double houseSpacing = totalLen / houseCount;
  static const double houseX = roadWidth / 2 + 8.0;
  static const int cWall = 0xFFEBE0CC;
  static const int cDoor = 0xFF6E4A2C;
  static const int cWindow = 0xFF9BD6EC;
  static const List<int> roofHexes = <int>[
    0xFFCF5140,
    0xFF4E86C6,
    0xFFE0973C,
    0xFF5AA090,
  ];
  static final vm.Matrix4 kHouseWall = vm.Matrix4.translationValues(0, 0.55, 0);
  static final vm.Matrix4 kHouseRoof =
      vm.Matrix4.translationValues(0, 1.55, 0)..rotateY(0.7853981633974483);
  static final vm.Matrix4 kHouseDoor =
      vm.Matrix4.translationValues(-0.32, 0.275, 0.77);
  static final vm.Matrix4 kHouseWindow =
      vm.Matrix4.translationValues(0.34, 0.62, 0.77);
  static const int cRock = 0xFF8C9198;
  static const int cBush = 0xFF52A63C;
  static const int decoCount = 40;
  static const int cLeafB = 0xFF7BBF3A;
  static const int cAutumn = 0xFFD1662E;
  static const int cFlowerA = 0xFFB760D9;
  static const int cFlowerB = 0xFFEC5C79;
  static const int grassCount = 320;
  static const int cGrassA = 0xFF69B84A;
  static const int cGrassB = 0xFF8AD05C;
  static const int cGrassC = 0xFF57A33F;

  static const int cLaneLine = 0xFFF4F2EA;
  static const double edgeLineX = roadWidth / 2 - 0.22;
  static const double shoulderW = 0.85;
  static const double shoulderX = roadWidth / 2 + shoulderW / 2;
  static const int cShoulder = 0xFF68645D;

  static const int hillCount = 6;
  static const int cHill = 0xFF477F43;

  static const int railCount = 30;
  static const int railPostCount = railCount ~/ 2;
  static const double railSpacing = totalLen / railCount;
  static const double railX = roadWidth / 2 + 0.62;
  static const double railY = roadTopY + 0.52;
  static const int cRail = 0xFFB9C4CE;
  static const int cRailPost = 0xFF8A939B;

  static const int signCount = 8;
  static const double signSpacing = totalLen / signCount;
  static const double signX = roadWidth / 2 + 1.45;
  static const int cSignPole = 0xFFEDEDE8;
  static const int cSignBoard = 0xFFD6DBE0;

  static const int rampCount = 2;
  static const double rampFirstDelay = 12.0;
  static const double rampInterval = 11.0;
  static const double rampImpulse = 11.5;
  static const double rampHalfZ = 1.5;
  static const int cRamp = 0xFF3F8FD8;
  static const int cRampEdge = 0xFF2B6DA6;

  static const int cGiftA = 0xFFE0533D;
  static const int cGiftB = 0xFFF2B33D;
  static const int cRibbon = 0xFFF7F3EA;
  static const int cBarrierA = 0xFFF04B3A;
  static const int cBarrierB = 0xFFE7E4DC;
  static const int cBarrierLeg = 0xFF5A5F66;
  static const int cContainer = 0xFF356B50;
  static const int cContainerB = 0xFF2E6B41;
  static const int cContainerR = 0xFFB2543A;

  static const int powerupCount = 3;
  static const double powerRadius = 0.48;
  static const double powerY = groundY + 0.5;
  static const double powerFirstDelay = 7.0;
  static const double powerInterval = 13.0;
  static const double powerGlow = 3.0;
  static const double magnetDuration = 6.0;
  static const double doubleDuration = 8.0;
  static const double magnetRange = 12.0;
  static const double magnetPull = 9.0;
  static const int cMagnet = 0xFFB56BFF;
  static const int cShield = 0xFF49B6FF;
  static const int cDouble = 0xFFFF5CA8;

  final Scene _scene = Scene();
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final FocusNode _focus = FocusNode();
  final math.Random _rng = math.Random();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  Phase _phase = Phase.menu;
  double _elapsed = 0;
  double _scrollZ = 0;
  int _lane = 0;
  double _runnerX = 0;
  double _prevRunnerX = 0;
  double _jumpY = 0;
  double _jumpV = 0;
  bool _grounded = true;
  double _obSpawnTimer = firstSpawnDelay;
  double _coinSpawnTimer = 2.0;
  double _score = 0;
  int _coinsCollected = 0;
  int _best = 0;
  bool _isNewBest = false;
  double _shakeT = 0;
  double _swipeDx = 0;
  double _swipeDy = 0;

  final List<_Score> _scores = <_Score>[];
  bool _enteringName = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  double get _curSpeed => gm.speedAt(_elapsed,
      base: baseSpeed, max: maxSpeed, rampPerSec: speedRampPerSec);

  InstancedMesh? _tilesA;
  InstancedMesh? _tilesB;
  InstancedMesh? _dashes;
  InstancedMesh? _coinMesh;
  final List<_Tree> _trees = <_Tree>[];
  final List<_TreeFoliage> _foliages = <_TreeFoliage>[];
  InstancedMesh? _treeTrunks;

  late final Texture2D _texAsphaltA;
  late final Texture2D _texAsphaltB;
  late final Texture2D _texGrass;
  late final Texture2D _texDirt;
  InstancedMesh? _houseWalls;
  InstancedMesh? _houseDoors;
  InstancedMesh? _houseWindows;
  final List<InstancedMesh> _houseRoofs = <InstancedMesh>[];
  final List<vm.Vector4> _houseData = <vm.Vector4>[];
  final List<int> _houseRoofSlot = <int>[];
  InstancedMesh? _rocks;
  InstancedMesh? _bushes;
  final List<vm.Vector3> _rockData = <vm.Vector3>[];
  final List<vm.Vector3> _bushData = <vm.Vector3>[];
  InstancedMesh? _flowersA;
  InstancedMesh? _flowersB;
  final List<vm.Vector3> _flowerAData = <vm.Vector3>[];
  final List<vm.Vector3> _flowerBData = <vm.Vector3>[];
  InstancedMesh? _grassA;
  InstancedMesh? _grassB;
  InstancedMesh? _grassC;
  final List<vm.Vector4> _grassAData = <vm.Vector4>[];
  final List<vm.Vector4> _grassBData = <vm.Vector4>[];
  final List<vm.Vector4> _grassCData = <vm.Vector4>[];
  InstancedMesh? _rails;
  InstancedMesh? _railPosts;
  InstancedMesh? _signPoles;
  InstancedMesh? _signBoards;
  final List<_Ramp> _ramps = <_Ramp>[];
  final List<_Obstacle> _obstacles = <_Obstacle>[];
  final List<_Coin> _coins = <_Coin>[];
  final List<_PowerUp> _powerups = <_PowerUp>[];
  final List<_ParticlePool> _particlePools = <_ParticlePool>[];
  late final Node _runner;
  Node? _dash;
  AnimationClip? _clipRun;
  AnimationClip? _clipIdle;
  AnimationClip? _clipJumpStart;
  AnimationClip? _clipJump;
  AnimationClip? _clipJumpLand;

  double _jumpStartAnimT = 0.0;
  double _jumpLandAnimT = 0.0;

  static const double _jumpStartAnimDuration = 0.18;
  static const double _jumpLandAnimDuration = 0.22;
  double _wRun = 0;
  double _wIdle = 1;
  double _wJump = 0;

  double _fps = 60;

  final bench.FrameBench? _bench =
      bench.kBenchEnabled ? bench.FrameBench() : null;

  double _rampSpawnTimer = rampFirstDelay;
  double _powerSpawnTimer = powerFirstDelay;
  double _magnetT = 0;
  double _doubleT = 0;
  bool _shield = false;

  final _Audio _audio = _Audio();
  static const List<double> volumes = <double>[0.0, 0.45, 0.9];
  int _volLevel = 2;

  int _quality = 0;

  double _appliedScale = -1;

  bool _worldLoadError = false;

  Camera? _lastCamera;
  Size _lastViewport = Size.zero;
  final List<_Popup> _popups = <_Popup>[];

  static double _laneX(int lane) => gm.laneX(lane, laneWidth);

  @override
  void initState() {
    super.initState();
    if (bench.kBenchEnabled) debugPrint('BENCH probe active');
    _setupSceneLook();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _buildWorld();
        if (!mounted) return;

        await _loadDash();
        if (!mounted) return;
      } catch (e, st) {
        debugPrint('World/model load failed: $e\n$st');
        if (mounted) setState(() => _worldLoadError = true);
      }
    });

    _ticker = createTicker(_onTick)..start();
    _loadScores();
    _audio.init();
    _loadVolume();
    _loadQuality();
    _loadLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onTick(Duration elapsed) {
    double dt = _last == Duration.zero
        ? 0
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (dt > 0) _fps += (1 / dt - _fps) * 0.06;
    final String? benchLine = _bench?.addFrame(dt);
    if (benchLine != null) debugPrint(benchLine);
    dt = gm.clampDt(dt, maxFrameDt);
    if (_shakeT > 0) _shakeT = math.max(0, _shakeT - dt);
    _updateParticles(dt);
    _update(dt);
    _updateDashAnim(dt);
    _updatePopups(dt);
    _repaint.value++;
  }

  void _update(double dt) {
    if (_phase == Phase.crashed) return;

    if (_phase == Phase.menu) {
      _scrollZ += baseSpeed * dt;
      _elapsed += dt;
      return;
    }

    final double v = _curSpeed;
    _elapsed += dt;
    _scrollZ += v * dt;
    _score += v * dt * 0.7 * (_doubleT > 0 ? 2.0 : 1.0);

    if (_magnetT > 0) _magnetT = math.max(0, _magnetT - dt);
    if (_doubleT > 0) _doubleT = math.max(0, _doubleT - dt);

    _prevRunnerX = _runnerX;
    final double targetX = _laneX(_lane);
    _runnerX += (targetX - _runnerX) * gm.smoothing(laneLerp, dt);

    if (!_grounded) {
      _jumpY += _jumpV * dt;
      _jumpV -= gravity * dt;
      if (_jumpY <= 0) {
        _jumpY = 0;
        _jumpV = 0;
        _grounded = true;

        _clipJumpStart?.weight = 0.0;
        _clipJump?.weight = 0.0;
        _jumpLandAnimT = _jumpLandAnimDuration;
        _clipJumpLand?.replay();
      }
    }

    _obSpawnTimer -= dt;
    if (_obSpawnTimer <= 0) {
      _spawnObstacle();
      _obSpawnTimer = obSpacing / v;
    }

    _coinSpawnTimer -= dt;
    if (_coinSpawnTimer <= 0) {
      _spawnCoinLine();
      _coinSpawnTimer = coinInterval;
    }

    _powerSpawnTimer -= dt;
    if (_powerSpawnTimer <= 0) {
      _spawnPowerUp();
      _powerSpawnTimer = powerInterval;
    }

    _rampSpawnTimer -= dt;
    if (_rampSpawnTimer <= 0) {
      _spawnRamp();
      _rampSpawnTimer = rampInterval;
    }

    for (final _Ramp r in _ramps) {
      if (!r.active) continue;
      r.z += v * dt;
      if (r.z > despawnZ) {
        r.active = false;
        continue;
      }
      if (_grounded &&
          (_runnerX - _laneX(r.lane)).abs() < 1.0 &&
          (runnerZ - r.z).abs() < rampHalfZ + runnerHalf) {
        _grounded = false;
        _jumpV = rampImpulse;
        _jumpStartAnimT = 0.0;
        _clipJumpStart?.replay();
        _clipJump?.weight = 0.0;
        _clipJumpLand?.weight = 0.0;
        _audio.jump();
      }
    }

    for (final _Obstacle o in _obstacles) {
      if (!o.active) continue;
      o.z += v * dt;
      if (o.z > despawnZ) {
        o.active = false;
        continue;
      }
      if (_hitsObstacle(o)) {
        if (_shield) {
          _shield = false;
          o.active = false;
          _spawnParticles(
              _laneX(o.lane), obstacleCenterY, o.z, 16, cShield, 5.0, 4.0);
          _audio.power();
        } else {
          _crash();
          return;
        }
      }
    }

    for (final _Coin c in _coins) {
      if (!c.active) continue;
      c.z += v * dt;
      if (c.z > despawnZ) {
        c.active = false;
        continue;
      }
      final double targetX = (_magnetT > 0 && (c.z - runnerZ).abs() < magnetRange)
          ? _runnerX
          : c.restX;
      c.cx += (targetX - c.cx) * gm.smoothing(magnetPull, dt);
      if (_collectsCoin(c)) {
        c.active = false;
        _coinsCollected++;
        _score += coinScore * (_doubleT > 0 ? 2 : 1);
        _spawnParticles(c.cx, c.y, c.z, 7, 0xFFFFC93C, 3.5, 3.0);
        _audio.coin();
        _spawnPopup(
            c.cx, c.y + 0.4, c.z, '+${coinScore * (_doubleT > 0 ? 2 : 1)}');
      }
    }

    for (final _PowerUp p in _powerups) {
      if (!p.active) continue;
      p.z += v * dt;
      if (p.z > despawnZ) {
        p.active = false;
        continue;
      }
      if (_collectsPower(p)) {
        p.active = false;
        _activatePower(p.kind);
        _spawnParticles(
            _laneX(p.lane), powerY, p.z, 18, _powerColor(p.kind), 5.5, 4.5);
        _audio.power();
      }
    }
  }

  void _spawnObstacle() {
    if (_elapsed > wallAfter && _rng.nextDouble() < wallChance) {
      final int openLane = _rng.nextInt(3) - 1;
      for (int lane = -1; lane <= 1; lane++) {
        if (lane != openLane) _placeObstacle(lane);
      }
    } else {
      _placeObstacle(_rng.nextInt(3) - 1);
    }
  }

  void _placeObstacle(int lane) {
    for (final _Obstacle o in _obstacles) {
      if (!o.active) {
        o.active = true;
        o.lane = lane;
        o.z = spawnZ;
        return;
      }
    }
  }

  void _spawnCoinLine() {
    final int pattern = _rng.nextInt(3);
    final int lane = _rng.nextInt(3) - 1;
    final int lane2 =
        pattern == 2 ? (lane == 0 ? (_rng.nextBool() ? 1 : -1) : 0) : lane;
    const int n = coinsPerLine;
    int placed = 0;
    for (final _Coin c in _coins) {
      if (placed >= n) break;
      if (c.active) continue;
      final double f = n > 1 ? placed / (n - 1) : 0.0;
      c.active = true;
      c.z = spawnZ - placed * coinGap;
      switch (pattern) {
        case 1:
          c.lane = lane;
          c.y = coinY + math.sin(f * math.pi) * coinArcH;
          c.restX = _laneX(lane);
          break;
        case 2:
          c.lane = f < 0.5 ? lane : lane2;
          c.y = coinY;
          c.restX = _laneX(lane) + (_laneX(lane2) - _laneX(lane)) * f;
          break;
        default:
          c.lane = lane;
          c.y = coinY;
          c.restX = _laneX(lane);
      }
      c.cx = c.restX;
      placed++;
    }
  }

  void _spawnRamp() {
    for (final _Ramp r in _ramps) {
      if (!r.active) {
        r.active = true;
        r.lane = _rng.nextInt(3) - 1;
        r.z = spawnZ;
        return;
      }
    }
  }

  bool _hitsObstacle(_Obstacle o) {
    final double runnerY = groundY + _jumpY;
    final double dx = (_runnerX - _laneX(o.lane)).abs();
    final double dy = (runnerY - obstacleCenterY).abs();
    final double dz = (runnerZ - o.z).abs();
    return dx < (runnerHalf + obHalfX) &&
        dy < (runnerHalf + obHalfY) &&
        dz < (runnerHalf + obHalfZ);
  }

  bool _collectsCoin(_Coin c) {
    final double runnerY = groundY + _jumpY;
    final double dx = (_runnerX - c.cx).abs();
    final double dy = (runnerY - c.y).abs();
    final double dz = (runnerZ - c.z).abs();
    return dx < 1.0 && dy < 1.8 && dz < 0.9;
  }

  void _spawnPowerUp() {
    for (final _PowerUp p in _powerups) {
      if (!p.active) {
        p.active = true;
        p.kind = PowerKind.values[_rng.nextInt(PowerKind.values.length)];
        p.lane = _rng.nextInt(3) - 1;
        p.z = spawnZ;
        p.material.baseColorFactor = _glowFromHex(_powerColor(p.kind), powerGlow);
        return;
      }
    }
  }

  bool _collectsPower(_PowerUp p) {
    final double runnerY = groundY + _jumpY;
    final double dx = (_runnerX - _laneX(p.lane)).abs();
    final double dy = (runnerY - powerY).abs();
    final double dz = (runnerZ - p.z).abs();
    return dx < 1.1 && dy < 1.8 && dz < 1.0;
  }

  void _activatePower(PowerKind k) {
    switch (k) {
      case PowerKind.magnet:
        _magnetT = magnetDuration;
        break;
      case PowerKind.shield:
        _shield = true;
        break;
      case PowerKind.doubleScore:
        _doubleT = doubleDuration;
        break;
    }
  }

  static int _powerColor(PowerKind k) {
    switch (k) {
      case PowerKind.magnet:
        return cMagnet;
      case PowerKind.shield:
        return cShield;
      case PowerKind.doubleScore:
        return cDouble;
    }
  }

  void _spawnParticles(double x, double y, double z, int count, int colorHex,
      double spread, double lift) {
    final _ParticlePool pool = _poolFor(colorHex);
    for (int n = 0; n < count; n++) {
      final _Particle? p = pool.free();
      if (p == null) return;
      p.active = true;
      p.pos.setValues(x, y, z);
      final double ang = _rng.nextDouble() * math.pi * 2;
      final double sp = spread * (0.4 + _rng.nextDouble());
      p.vel.setValues(math.cos(ang) * sp, lift * (0.6 + _rng.nextDouble()),
          math.sin(ang) * sp);
      p.maxLife = 0.5 + _rng.nextDouble() * 0.35;
      p.life = p.maxLife;
    }
  }

  _ParticlePool _poolFor(int colorHex) {
    for (final _ParticlePool pool in _particlePools) {
      if (pool.colorHex == colorHex) return pool;
    }
    return _particlePools.first;
  }

  void _updateParticles(double dt) {
    for (final _ParticlePool pool in _particlePools) {
      for (final _Particle p in pool.parts) {
        if (!p.active) continue;
        p.life -= dt;
        if (p.life <= 0) {
          p.active = false;
          continue;
        }
        p.vel.y -= particleGravity * dt;
        p.pos.x += p.vel.x * dt;
        p.pos.y += p.vel.y * dt;
        p.pos.z += p.vel.z * dt;
      }
    }
  }

  int? _placeFor(int s) {
    if (s <= 0) return null;
    int place = 1;
    for (final _Score e in _scores) {
      if (s > e.score) break;
      place++;
    }
    return place <= 5 ? place : null;
  }

  static String _ordinal(int n) => gm.ordinal(n);

  bool _isHighScore(int s) =>
      s > 0 && (_scores.length < 5 || s > _scores.last.score);

  void _spawnPopup(double wx, double wy, double wz, String text) {
    final Camera? cam = _lastCamera;
    if (cam == null) return;
    final Offset? o = cam.worldToScreen(vm.Vector3(wx, wy, wz), _lastViewport);
    if (o == null) return;
    _popups.add(_Popup(text, o.dx, o.dy));
    if (_popups.length > 14) _popups.removeAt(0);
  }

  void _updatePopups(double dt) {
    for (int i = _popups.length - 1; i >= 0; i--) {
      final _Popup p = _popups[i];
      p.age += dt;
      p.y -= 46 * dt;
      if (p.age >= _Popup.life) _popups.removeAt(i);
    }
  }

  void _crash() {
    if (_phase != Phase.playing) return;
    final int s = _score.round();
    _isNewBest = s > _best;
    _best = math.max(_best, s);
    _shakeT = shakeDuration;
    _spawnParticles(_runnerX, groundY + _jumpY, runnerZ, 22, 0xFFE0533D, 5.0, 5.0);
    _audio.crash();
    final bool high = _isHighScore(s);
    setState(() {
      _phase = Phase.crashed;
      _enteringName = high;
      _nameCtrl.text = '';
    });
    if (high) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  void _submitName() {
    final String raw = _nameCtrl.text.trim().replaceAll('|', ' ');
    final String name =
        raw.isEmpty ? 'YOU' : (raw.length > 12 ? raw.substring(0, 12) : raw);
    _scores.add(_Score(name, _score.round()));
    _scores.sort((a, b) => b.score.compareTo(a.score));
    if (_scores.length > 5) _scores.removeRange(5, _scores.length);
    _saveScores();
    setState(() => _enteringName = false);
    _focus.requestFocus();
  }

  Future<void> _loadScores() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw =
          prefs.getStringList('leaderboard.v1') ?? <String>[];
      final List<_Score> loaded = <_Score>[];
      for (final String e in raw) {
        final int idx = e.indexOf('|');
        if (idx <= 0) continue;
        final int? sc = int.tryParse(e.substring(0, idx));
        if (sc == null) continue;
        loaded.add(_Score(e.substring(idx + 1), sc));
      }
      loaded.sort((a, b) => b.score.compareTo(a.score));
      if (!mounted) return;
      setState(() {
        _scores
          ..clear()
          ..addAll(loaded.take(5));
        _best = _scores.isNotEmpty ? _scores.first.score : 0;
      });
    } catch (_) {}
  }

  Future<void> _saveScores() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'leaderboard.v1',
        _scores.map((_Score s) => '${s.score}|${s.name}').toList(),
      );
    } catch (_) {}
  }

  void _resetRun() {
    _elapsed = 0;
    _scrollZ = 0;
    _lane = 0;
    _runnerX = 0;
    _prevRunnerX = 0;
    _jumpY = 0;
    _jumpV = 0;
    _grounded = true;
    _obSpawnTimer = firstSpawnDelay;
    _coinSpawnTimer = 2.0;
    _score = 0;
    _coinsCollected = 0;
    for (final _Obstacle o in _obstacles) {
      o.active = false;
    }
    for (final _Coin c in _coins) {
      c.active = false;
    }
    for (final _PowerUp p in _powerups) {
      p.active = false;
    }
    for (final _Ramp r in _ramps) {
      r.active = false;
    }
    for (final _ParticlePool pool in _particlePools) {
      for (final _Particle p in pool.parts) {
        p.active = false;
      }
    }
    _rampSpawnTimer = rampFirstDelay;
    _powerSpawnTimer = powerFirstDelay;
    _magnetT = 0;
    _doubleT = 0;
    _shield = false;
    _shakeT = 0;
  }

  void _startGame() {
    _resetRun();
    setState(() {
      _phase = Phase.playing;
      _enteringName = false;
    });
    _focus.requestFocus();
  }

  void _goMenu() {
    _resetRun();
    setState(() {
      _phase = Phase.menu;
      _enteringName = false;
    });
    _focus.requestFocus();
  }

  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = e.logicalKey;

    if (_phase == Phase.menu) {
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
        _startGame();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (_phase == Phase.crashed) {
      if (_enteringName) return KeyEventResult.ignored;
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
        _startGame();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyM || k == LogicalKeyboardKey.escape) {
        _goMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _moveLane(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      _moveLane(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW) {
      _jump();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveLane(int dir) {
    if (_phase != Phase.playing) return;
    _lane = dir > 0 ? math.min(1, _lane + 1) : math.max(-1, _lane - 1);
  }

  void _jump() {
    if (_phase != Phase.playing) return;
    if (_grounded) {
      _grounded = false;
      _jumpV = jumpImpulse;
      _jumpStartAnimT = 0.0;
      _clipJumpStart?.replay();
      _clipJump?.weight = 0.0;
      _clipJumpLand?.weight = 0.0;
      _audio.jump();
    }
  }

  void _handleSwipe() {
    if (_phase != Phase.playing) return;
    if (_swipeDx.abs() > _swipeDy.abs() && _swipeDx.abs() > 18) {
      _moveLane(_swipeDx > 0 ? 1 : -1);
    } else if (_swipeDy < -18) {
      _jump();
    }
  }

  Future<void> _buildWorld() async {
    _buildTextures();

    final Node grassL = Node(
        mesh: Mesh(CuboidGeometry(vm.Vector3(groundHalfW, 0.4, groundLen)),
            _textured(_texGrass)))
      ..localTransform = vm.Matrix4.translationValues(
          -(roadWidth / 2 + groundHalfW / 2), roadTopY - 0.2, -20);
    final Node grassR = Node(
        mesh: Mesh(CuboidGeometry(vm.Vector3(groundHalfW, 0.4, groundLen)),
            _textured(_texGrass)))
      ..localTransform = vm.Matrix4.translationValues(
          roadWidth / 2 + groundHalfW / 2, roadTopY - 0.2, -20);
    final Node roadBed =
        _litBox(vm.Vector3(roadWidth + 0.1, 0.3, groundLen), cAsphaltB)
          ..localTransform =
              vm.Matrix4.translationValues(0, roadTopY - 0.26, -20);
    grassL.shadowStatic = true;
    grassR.shadowStatic = true;
    roadBed.shadowStatic = true;
    _scene.add(grassL);
    _scene.add(grassR);
    _scene.add(roadBed);

    for (final double side in <double>[-1.0, 1.0]) {
      _scene.add(Node(
          mesh: Mesh(CuboidGeometry(vm.Vector3(shoulderW, 0.08, groundLen)),
              _textured(_texDirt)))
        ..shadowStatic = true
        ..localTransform = vm.Matrix4.translationValues(
            side * shoulderX, roadTopY - 0.03, -20));
      _scene.add(_litBox(vm.Vector3(0.16, 0.06, groundLen), cLaneLine)
        ..shadowStatic = true
        ..localTransform = vm.Matrix4.translationValues(
            side * edgeLineX, roadTopY - 0.005, -20));
    }

    for (int i = 0; i < hillCount; i++) {
      final double side = i.isEven ? -1.0 : 1.0;
      final double w = 14.0 + _rng.nextDouble() * 10.0;
      final double h = 6.0 + _rng.nextDouble() * 6.0;
      final double hx = side * (38.0 + _rng.nextDouble() * 30.0);
      final double hz = -40.0 - _rng.nextDouble() * 18.0;
      final vm.Matrix4 hm =
          vm.Matrix4.translationValues(hx, roadTopY - h * 0.55, hz)
            ..scaleByDouble(w, h, w * 0.7, 1.0);
      _scene.add(Node(
          mesh: Mesh(IcosphereGeometry(radius: 1.0, subdivisions: 2),
              _matte(cHill)))
        ..shadowStatic = true
        ..localTransform = hm);
    }

    const String roadAsset = 'assets/road/road-straight.glb';

    for (int i = 0; i < tileCount; i++) {
      final Node road = await Node.fromGlbAsset(roadAsset);

      road.localTransform = vm.Matrix4.translationValues(
        0,
        0,
        -i * segLen,
      );

      _scene.add(road);
    }

    _dashes = InstancedMesh(
        geometry: CuboidGeometry(vm.Vector3(0.16, 0.06, 1.5)),
        material: _matte(cLaneLine));
    for (int k = 0; k < dashCount * 2; k++) {
      _dashes!.addInstance(vm.Matrix4.identity());
    }
    _scene.add(Node()..addComponent(InstancedMeshComponent(_dashes!)));
    await _buildCityProps();
    for (int i = 0; i < rampCount; i++) {
      final Node n = _rampNode();
      _ramps.add(_Ramp(n));
      _scene.add(n);
    }

    for (int i = 0; i < obstacleCount; i++) {
      final String asset = switch (i % 6) {
        0 => 'assets/city_props/barrel_02_big_red.glb',
        1 => 'assets/city_props/barrel_02_big_blue.glb',
        2 => 'assets/city_props/simple_barricade_01_large.glb',
        3 => 'assets/city_props/type_ii_barricade_01_large.glb',
        4 => 'assets/city_props/garbage_collector_green_large.glb',
        _ => 'assets/city_props/garbage_collector_red_large.glb',
      };

      final Node n = await Node.fromGlbAsset(asset);
      _obstacles.add(_Obstacle(n));
      _scene.add(n);
    }
    final PhysicallyBasedMaterial coinMat = PhysicallyBasedMaterial()
      ..baseColorFactor = _linearFromHex(cCoin)
      ..roughnessFactor = 0.3
      ..metallicFactor = 1.0;
    _coinMesh = InstancedMesh(
        geometry: CylinderGeometry(
            bottomRadius: coinRadius,
            topRadius: coinRadius,
            height: 0.1,
            radialSegments: 14),
        material: coinMat);
    for (int i = 0; i < coinCount; i++) {
      _coins.add(_Coin());
      _coinMesh!.addInstance(vm.Matrix4.identity());
    }
    _scene.add(Node()..addComponent(InstancedMeshComponent(_coinMesh!)));
    for (int i = 0; i < powerupCount; i++) {
      final UnlitMaterial mat = UnlitMaterial()
        ..baseColorFactor = _glowFromHex(cMagnet, powerGlow);
      final Node n = Node(
          mesh: Mesh(
              IcosphereGeometry(radius: powerRadius, subdivisions: 2), mat));
      _powerups.add(_PowerUp(n, mat));
      _scene.add(n);
    }
    for (final int hex in particleColors) {
      final UnlitMaterial mat = UnlitMaterial()
        ..baseColorFactor = _glowFromHex(hex, particleGlow);
      final InstancedMesh mesh = InstancedMesh(
          geometry: CuboidGeometry(vm.Vector3(0.18, 0.18, 0.18)),
          material: mat);
      _particlePools.add(_ParticlePool(hex, mesh, particlesPerColor));
      _scene.add(Node()..addComponent(InstancedMeshComponent(mesh)));
    }

    _runner = _box(vm.Vector3(1.0, 1.0, 1.0), debug: true);
    _scene.add(_runner);
  }

  void _setupSceneLook() {
    _scene.root.addComponent(
      DirectionalLightComponent(
        DirectionalLight(
          direction: vm.Vector3(-0.5, -1.0, -0.42),
          intensity: sunIntensity,
          castsShadow: true,
          shadowCascadeCount: shadowCascades,
          shadowMapResolution: shadowMapRes,
          shadowMaxDistance: shadowDistance,
          shadowDepthBias: 0.06,
          shadowNormalBias: 0.09,
        ),
      ),
    );
    _scene.environmentIntensity = envIntensity;

    final vm.Vector4 f = _linearFromHex(cFogDay);
    _scene.fog
      ..enabled = true
      ..mode = FogMode.linear
      ..color = vm.Vector3(f.r, f.g, f.b)
      ..start = fogStartDay
      ..end = fogEndDay;

    _scene.postProcess.bloom
      ..enabled = true
      ..threshold = 1.1
      ..intensity = 0.28
      ..scatter = 0.6;
    _scene.postProcess.colorGrading
      ..enabled = true
      ..contrast = 1.0
      ..saturation = 1.12;
  }

  Future<void> _loadDash() async {
    try {
      final Node dash = await Node.fromGlbAsset(dashAsset);
      if (!mounted) return;
      final runClip =
          _makeClip(dash, const <String>['Sprint'], loop: true);
      if (runClip != null) {
        runClip.weight = 0;
        runClip.play();
      }
      _clipRun = runClip;

      final idleClip =
          _makeClip(dash, const <String>['Walk'], loop: true);
      if (idleClip != null) {
        idleClip.weight = 1;
        idleClip.play();
      }
      _clipIdle = idleClip;

      final jumpStartClip =
          _makeClip(dash, const <String>['Jump Start'], loop: false);
      jumpStartClip?.weight = 0;
      _clipJumpStart = jumpStartClip;

      final jumpClip =
          _makeClip(dash, const <String>['Jump'], loop: true);
      jumpClip?.weight = 0;
      _clipJump = jumpClip;

      final jumpLandClip =
          _makeClip(dash, const <String>['Jump Land'], loop: false);
      jumpLandClip?.weight = 0;
      _clipJumpLand = jumpLandClip;

      _scene.add(dash);
      _dash = dash;
    } catch (e) {
      debugPrint('Dash model failed to load; keeping placeholder cube: $e');
    }
  }

  AnimationClip? _makeClip(Node node, List<String> names, {required bool loop}) {
    for (final String n in names) {
      final anim = node.findAnimationByName(n);
      if (anim != null) return node.createAnimationClip(anim)..loop = loop;
    }
    if (node.parsedAnimations.isNotEmpty) {
      return node.createAnimationClip(node.parsedAnimations.first)..loop = loop;
    }
    return null;
  }

  void _updateDashAnim(double dt) {
    if (_dash == null) return;

    final bool playing = _phase == Phase.playing;

    if (!playing) {
      _jumpStartAnimT = 0.0;
      _jumpLandAnimT = 0.0;
      _clipIdle?.weight = 1.0;
      _clipRun?.weight = 0.0;
      _clipJumpStart?.weight = 0.0;
      _clipJump?.weight = 0.0;
      _clipJumpLand?.weight = 0.0;
      return;
    }

    if (!_grounded) {
      _jumpStartAnimT += dt;

      final bool inJumpStart =
          _jumpStartAnimT < _jumpStartAnimDuration;

      _clipIdle?.weight = 0.0;
      _clipRun?.weight = 0.0;
      _clipJumpLand?.weight = 0.0;

      if (inJumpStart) {
        _clipJumpStart?.weight = 1.0;
        _clipJump?.weight = 0.0;
      } else {
        _clipJumpStart?.weight = 0.0;
        _clipJump?.weight = 1.0;
      }
      return;
    }

    _clipIdle?.weight = 0.0;
    _clipJumpStart?.weight = 0.0;
    _clipJump?.weight = 0.0;

    if (_jumpLandAnimT > 0.0) {
      _jumpLandAnimT = math.max(0.0, _jumpLandAnimT - dt);
      _clipRun?.weight = 0.0;
      _clipJumpLand?.weight = 1.0;
    } else {
      _clipRun?.weight = 1.0;
      _clipJumpLand?.weight = 0.0;
    }
  }

  Node _box(vm.Vector3 size,
      {int? colorHex, bool debug = false, double glow = 1.0}) {
    final UnlitMaterial material = UnlitMaterial();
    if (debug) material.vertexColorWeight = 1.0;
    if (colorHex != null) {
      material.baseColorFactor = _glowFromHex(colorHex, glow);
    }
    return Node(mesh: Mesh(CuboidGeometry(size, debugColors: debug), material));
  }

  Node _litBox(vm.Vector3 size, int colorHex,
      {double rough = 0.9, double metal = 0.0}) {
    final PhysicallyBasedMaterial material = PhysicallyBasedMaterial()
      ..baseColorFactor = _linearFromHex(colorHex)
      ..roughnessFactor = rough
      ..metallicFactor = metal;
    return Node(mesh: Mesh(CuboidGeometry(size), material));
  }

  PhysicallyBasedMaterial _matte(int colorHex) => PhysicallyBasedMaterial()
    ..baseColorFactor = _linearFromHex(colorHex)
    ..roughnessFactor = 1.0;

  PhysicallyBasedMaterial _textured(Texture2D tex, {double rough = 1.0}) =>
      PhysicallyBasedMaterial()
        ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
        ..baseColorTexture = tex
        ..roughnessFactor = rough;

  void _buildTextures() {
    _texAsphaltA = Texture2D.fromPixels(
        gt.asphaltPixels(256, cAsphaltA & 0xFFFFFF), 256, 256);
    _texAsphaltB = Texture2D.fromPixels(
        gt.asphaltPixels(256, cAsphaltB & 0xFFFFFF, seed: 29), 256, 256);
    _texGrass = Texture2D.fromPixels(
        gt.grassPixels(128, cGrass & 0xFFFFFF, cGrassB & 0xFFFFFF), 128, 128);
    _texDirt = Texture2D.fromPixels(
        gt.dirtPixels(128, cShoulder & 0xFFFFFF), 128, 128);
  }

  int _foliageColor(bool pine) {
    final int r = _rng.nextInt(10);
    if (pine) return r < 7 ? cPine : cLeafB;
    if (r < 5) return cLeaf;
    if (r < 7) return cLeafB;
    if (r < 8) return cPine;
    return cAutumn;
  }

  Future<void> _buildCityProps() async {
    const List<String> assets = <String>[
      'assets/city_props/garbage_collector_blue_large.glb',
      'assets/city_props/garbage_collector_green_large.glb',
      'assets/city_props/garbage_collector_red_large.glb',
      'assets/city_props/simple_barricade_01_large.glb',
      'assets/city_props/type_ii_barricade_01_large.glb',
      'assets/city_props/barrel_02_big_yellow.glb',
    ];

    const double spacing = 8.0;
    const int countPerSide = 18;

    for (int i = 0; i < countPerSide; i++) {
      final String asset = assets[i % assets.length];

      final Node left = await Node.fromGlbAsset(asset);
      left.localTransform = vm.Matrix4.translationValues(
        -4.2,
        0,
        -i * spacing,
      );
      _scene.add(left);

      final Node right = await Node.fromGlbAsset(
        assets[(i + 3) % assets.length],
      );
      right.localTransform = vm.Matrix4.translationValues(
        4.2,
        0,
        -i * spacing - 4.0,
      );
      _scene.add(right);
    }
  }

  void _buildTrees() {
    final List<bool> pines = <bool>[];
    final List<double> scales = <double>[];
    final List<double> xs = <double>[];
    final List<double> phases = <double>[];
    final List<_TreeFoliage> groups = <_TreeFoliage>[];
    final List<int> slots = <int>[];

    _TreeFoliage groupFor(int hex) {
      for (final _TreeFoliage f in _foliages) {
        if (f.colorHex == hex) return f;
      }
      final _TreeFoliage f = _TreeFoliage(hex);
      _foliages.add(f);
      return f;
    }

    for (int j = 0; j < postCount; j++) {
      for (int side = 0; side < 2; side++) {
        final bool pine = side == 0 ? j.isEven : j.isOdd;
        final _TreeFoliage g = groupFor(_foliageColor(pine));
        pines.add(pine);
        scales.add(1.15 + _rng.nextDouble() * 0.95);
        xs.add(side == 0 ? -treeX : treeX);
        phases.add(j * postSpacing);
        groups.add(g);
        slots.add(pine ? g.pineCount++ : g.roundCount++);
      }
    }

    _treeTrunks = InstancedMesh(
        geometry: CylinderGeometry(
            bottomRadius: 0.13,
            topRadius: 0.11,
            height: trunkH,
            radialSegments: 8),
        material: _matte(cTrunk));
    for (int i = 0; i < pines.length; i++) {
      _treeTrunks!.addInstance(vm.Matrix4.identity());
    }
    _scene.add(Node()..addComponent(InstancedMeshComponent(_treeTrunks!)));

    for (final _TreeFoliage f in _foliages) {
      if (f.pineCount > 0) {
        for (final List<double> t in _pineTierDims) {
          final InstancedMesh m = InstancedMesh(
              geometry: CylinderGeometry(
                  bottomRadius: t[0],
                  topRadius: 0.0,
                  height: t[1],
                  radialSegments: 12),
              material: _matte(f.colorHex));
          for (int i = 0; i < f.pineCount; i++) {
            m.addInstance(vm.Matrix4.identity());
          }
          f.pineTiers.add(m);
          _scene.add(Node()..addComponent(InstancedMeshComponent(m)));
        }
      }
      if (f.roundCount > 0) {
        for (int b = 0; b < _roundBlobRadii.length; b++) {
          final InstancedMesh m = InstancedMesh(
              geometry: IcosphereGeometry(
                  radius: _roundBlobRadii[b], subdivisions: 2),
              material: _matte(f.colorHex));
          final int per = b == 1 ? 2 : 1;
          for (int i = 0; i < f.roundCount * per; i++) {
            m.addInstance(vm.Matrix4.identity());
          }
          f.roundBlobs.add(m);
          _scene.add(Node()..addComponent(InstancedMeshComponent(m)));
        }
      }
    }

    for (int i = 0; i < pines.length; i++) {
      _trees.add(_Tree(
        x: xs[i],
        phaseZ: phases[i],
        scale: scales[i],
        pine: pines[i],
        foliage: groups[i],
        slot: slots[i],
        trunkSlot: i,
      ));
    }
  }

  Node _giftBox({required int boxHex}) {
    final Node root = Node();

    const double s = 0.92;
    const double half = s / 2;

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(s, s, s)),
          _matte(boxHex),
        ),
      )..localTransform = vm.Matrix4.translationValues(0, half, 0),
    );

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(0.62, 0.46, 0.035)),
          _matte(cRibbon),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, 0.48, s / 2 + 0.025),
    );

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(0.12, s + 0.04, 0.035)),
          _matte(cRibbon),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, half, s / 2 + 0.04),
    );

    root.add(
      Node(
        mesh: Mesh(
          IcosphereGeometry(radius: 0.13, subdivisions: 2),
          _matte(cRibbon),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, s + 0.10, 0),
    );

    return root;
  }

  Node _barrier() {
    final Node root = Node();

    for (final double dx in <double>[-0.5, 0.5]) {
      root.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(0.12, 0.88, 0.12)),
            _matte(cBarrierLeg),
          ),
        )..localTransform =
            vm.Matrix4.translationValues(dx, 0.44, 0),
      );
    }

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(1.18, 0.34, 0.18)),
          _matte(cBarrierA),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, 0.72, 0),
    );

    for (int i = 0; i < 5; i++) {
      root.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(0.20, 0.24, 0.195)),
            _matte(i.isEven ? cBarrierB : cBarrierA),
          ),
        )..localTransform =
            vm.Matrix4.translationValues(-0.40 + i * 0.20, 0.72, 0),
      );
    }

    root.add(
      Node(
        mesh: Mesh(
          IcosphereGeometry(radius: 0.09, subdivisions: 2),
          _matte(cBarrierA),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, 0.98, 0),
    );

    return root;
  }

  Node _container({required int bodyHex}) {
    final Node root = Node();

    const double w = 1.16;
    const double h = 0.96;
    const double d = 0.96;

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(w, h, d)),
          _matte(bodyHex),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, h / 2, 0),
    );

    for (final double y in <double>[0.07, h - 0.07]) {
      root.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(w + 0.04, 0.12, d + 0.04)),
            _matte(cContainerB),
          ),
        )..localTransform =
            vm.Matrix4.translationValues(0, y, 0),
      );
    }

    for (int i = 0; i < 5; i++) {
      root.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(0.075, h - 0.22, 0.045)),
            _matte(cContainerB),
          ),
        )..localTransform = vm.Matrix4.translationValues(
            -0.40 + i * 0.20,
            h / 2,
            d / 2 + 0.025,
          ),
      );
    }

    root.add(
      Node(
        mesh: Mesh(
          IcosphereGeometry(radius: 0.12, subdivisions: 2),
          _matte(cContainerB),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, 0.52, d / 2 + 0.07),
    );

    return root;
  }

  Node _rampNode() {
    final Node root = Node();

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(
            vm.Vector3(1.7, 0.18, rampHalfZ * 2),
          ),
          _matte(cRamp),
        ),
      )..localTransform =
          vm.Matrix4.translationValues(0, 0.09, 0),
    );

    final vm.Matrix4 lip =
        vm.Matrix4.translationValues(
          0,
          0.07,
          rampHalfZ + 0.18,
        )..rotateX(0.42);

    root.add(
      Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(1.7, 0.07, 0.5)),
          _matte(cRampEdge),
        ),
      )..localTransform = lip,
    );

    for (final double dx in <double>[-0.88, 0.88]) {
      root.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(
              vm.Vector3(0.09, 0.28, rampHalfZ * 2),
            ),
            _matte(cRampEdge),
          ),
        )..localTransform =
            vm.Matrix4.translationValues(dx, 0.14, 0),
      );
    }

    return root;
  }

  void _scatterDeco(InstancedMesh mesh, List<vm.Vector3> data, double minScale,
      double scaleRange) {
    for (int i = 0; i < decoCount; i++) {
      final double side = _rng.nextBool() ? 1.0 : -1.0;
      final double x = side * (roadWidth / 2 + 1.6 + _rng.nextDouble() * 24);
      final double phase = _rng.nextDouble() * totalLen;
      final double sc = minScale + _rng.nextDouble() * scaleRange;
      data.add(vm.Vector3(x, phase, sc));
      mesh.addInstance(vm.Matrix4.identity());
    }
  }

  void _scatterGrass(InstancedMesh mesh, List<vm.Vector4> data) {
    for (int i = 0; i < grassCount; i++) {
      final double side = _rng.nextBool() ? 1.0 : -1.0;
      final double x =
          side * (roadWidth / 2 + shoulderW + _rng.nextDouble() * 15);
      final double phase = _rng.nextDouble() * totalLen;
      final double sc = 0.7 + _rng.nextDouble() * 1.05;
      final double yaw = _rng.nextDouble() * 6.283;
      data.add(vm.Vector4(x, phase, sc, yaw));
      mesh.addInstance(vm.Matrix4.identity());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _focus.dispose();
    _nameFocus.dispose();
    _nameCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _loadVolume() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int lvl = prefs.getInt('volume.v1') ?? 2;
      if (!mounted) return;
      setState(() => _volLevel = lvl.clamp(0, volumes.length - 1));
      _applyVolume();
    } catch (_) {}
  }

  void _applyVolume() => _audio.volume = volumes[_volLevel];

  void _syncRenderScale(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final Size size = MediaQuery.sizeOf(context);
    final double nativePixels = size.width * dpr * size.height * dpr;
    final double fit = nativePixels <= 0
        ? 1.0
        : math.min(1.0, math.sqrt(pixelBudget / nativePixels));
    final double target =
        math.max(minRenderScale, fit * qualityScales[_quality]);
    if ((target - _appliedScale).abs() < 0.01) return;
    _appliedScale = target;
    _scene.renderScale = target;
  }

  void _applyQuality() => _appliedScale = -1;

  Future<void> _loadQuality() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int q = prefs.getInt('quality.v1') ?? 1;
      if (!mounted) return;
      setState(() => _quality = q.clamp(0, qualityScales.length - 1));
      _applyQuality();
    } catch (_) {}
  }

  void _cycleQuality() {
    setState(() => _quality = (_quality + 1) % qualityScales.length);
    _applyQuality();
    _focus.requestFocus();
    _saveQuality();
  }

  void _setQuality(int q) {
    if (q == _quality) return;
    setState(() => _quality = q.clamp(0, qualityScales.length - 1));
    _applyQuality();
    _saveQuality();
  }

  void _setVolumeLevel(int lvl) {
    if (lvl == _volLevel) return;
    setState(() => _volLevel = lvl.clamp(0, volumes.length - 1));
    _applyVolume();
    _saveVolume();
  }

  Future<void> _loadLanguage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString('language.v1');
      if (saved == 'ar') {
        AppStrings.language.value = AppLanguage.ar;
      } else if (saved == 'en') {
        AppStrings.language.value = AppLanguage.en;
      }
    } catch (_) {}
  }

  Future<void> _setLanguage(AppLanguage lang) async {
    if (AppStrings.language.value == lang) return;
    setState(() => AppStrings.language.value = lang);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language.v1', lang == AppLanguage.ar ? 'ar' : 'en');
    } catch (_) {}
  }

  void _openSettings() {
    _focus.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141B2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppStrings.t('settings'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _settingsSectionLabel(AppStrings.t('language')),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _settingsChoiceChip(
                            'English',
                            AppStrings.language.value == AppLanguage.en,
                            () {
                              _setLanguage(AppLanguage.en);
                              setSheetState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _settingsChoiceChip(
                            'العربية',
                            AppStrings.language.value == AppLanguage.ar,
                            () {
                              _setLanguage(AppLanguage.ar);
                              setSheetState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _settingsSectionLabel(AppStrings.t('sound_effects')),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        for (int i = 0; i < volumes.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  left: i == 0 ? 0 : 5,
                                  right: i == volumes.length - 1 ? 0 : 5),
                              child: _settingsChoiceChip(
                                AppStrings.t(
                                    <String>['off', 'low', 'high'][i]),
                                _volLevel == i,
                                () {
                                  _setVolumeLevel(i);
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _settingsSectionLabel(AppStrings.t('render_quality')),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        for (int i = 0; i < qualityScales.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  left: i == 0 ? 0 : 5,
                                  right:
                                      i == qualityScales.length - 1 ? 0 : 5),
                              child: _settingsChoiceChip(
                                AppStrings.t(<String>[
                                  'quality_high',
                                  'quality_balanced',
                                  'quality_fast'
                                ][i]),
                                _quality == i,
                                () {
                                  _setQuality(i);
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => _focus.requestFocus());
  }

  Widget _settingsSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _settingsChoiceChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cTeal.withValues(alpha: 0.18) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cTeal : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? cTeal : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuality() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quality.v1', _quality);
    } catch (_) {}
  }

  void _cycleVolume() {
    setState(() => _volLevel = (_volLevel + 1) % volumes.length);
    _applyVolume();
    _focus.requestFocus();
    _saveVolume();
  }

  Future<void> _saveVolume() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('volume.v1', _volLevel);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _syncRenderScale(context);
    return Scaffold(
      backgroundColor: cBg,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent e) => _onKey(e),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_enteringName) return;
            _focus.requestFocus();
            if (_phase == Phase.menu) _startGame();
          },
          onPanStart: (DragStartDetails d) {
            _swipeDx = 0;
            _swipeDy = 0;
          },
          onPanUpdate: (DragUpdateDetails d) {
            _swipeDx += d.delta.dx;
            _swipeDy += d.delta.dy;
          },
          onPanEnd: (DragEndDetails d) => _handleSwipe(),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(cSkyTop), Color(cSkyBot)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _repaint,
                    builder: (BuildContext context, int tick, Widget? child) =>
                        CustomPaint(painter: _CloudPainter(_elapsed)),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GamePainter(state: this, repaint: _repaint),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: Text(
                  AppStrings.t('app_name').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      onPressed: _cycleVolume,
                      tooltip: AppStrings.t('sound_effects'),
                      icon: Icon(
                        _volLevel == 0
                            ? Icons.volume_off_rounded
                            : _volLevel == 1
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        color: _volLevel == 0 ? Colors.white38 : cTeal,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: _openSettings,
                      tooltip: AppStrings.t('settings'),
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              _popupLayer(),
              if (_phase == Phase.playing) _hud(),
              if (_phase == Phase.playing)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    AppStrings.t('hint_controls'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              if (_phase == Phase.menu) _menuOverlay(),
              if (_phase == Phase.crashed) _crashedOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popupLayer() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: _repaint,
          builder: (BuildContext context, int _, Widget? __) {
            return Stack(
              children: <Widget>[
                for (final _Popup p in _popups)
                  Positioned(
                    left: p.x - 32,
                    top: p.y - 14,
                    child: Opacity(
                      opacity: (1 - p.age / _Popup.life).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: cGold,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: Colors.black26, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            p.text,
                            style: const TextStyle(
                              color: cGold,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black87, blurRadius: 2),
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hud() {
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: _repaint,
          builder: (BuildContext context, int _, Widget? __) {
            return Column(
              children: <Widget>[
                _scoreCapsule(),
                const SizedBox(height: 6),
                _bestLine(),
                _powerChips(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _scoreCapsule() {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 9),
      decoration: BoxDecoration(
        color: const Color(0xE60E1A2B),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cGold.withValues(alpha: 0.85), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${_score.round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: cGold, borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(width: 5),
              Text('$_coinsCollected',
                  style: const TextStyle(
                      color: cGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text('${_curSpeed.round()} m/s',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(
                  '${_fps.round()} fps  ·  ${(_appliedScale * 100).round()}%',
                  style: TextStyle(
                      color: _fps < 45 ? cRed : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bestLine() {
    final int cur = _score.round();
    final bool beating = _best > 0 && cur > _best;
    if (_best <= 0 && !beating) return const SizedBox.shrink();
    return Text(
      beating
          ? AppStrings.t('new_best')
          : '${AppStrings.t('best_label')}  $_best',
      style: TextStyle(
        color: beating ? cGold : Colors.white38,
        fontSize: 13,
        fontWeight: beating ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: beating ? 1.5 : 0.5,
      ),
    );
  }

  Widget _powerChips() {
    final List<Widget> chips = <Widget>[];
    if (_magnetT > 0) {
      chips.add(_powerChip('MAGNET  ${_magnetT.ceil()}', const Color(cMagnet)));
    }
    if (_doubleT > 0) {
      chips.add(_powerChip('×2  ${_doubleT.ceil()}', const Color(cDouble)));
    }
    if (_shield) chips.add(_powerChip('SHIELD', const Color(cShield)));
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: chips),
    );
  }

  Widget _powerChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.85)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _menuOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppStrings.t('app_name'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.t('tagline'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              if (_worldLoadError) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '⚠ ${AppStrings.t('world_load_warning')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: cRed, fontSize: 12),
                ),
              ],
              const SizedBox(height: 26),
              _leaderboard(),
              const SizedBox(height: 22),
              _primaryButton(AppStrings.t('play'), _startGame),
              const SizedBox(height: 10),
              Text(
                AppStrings.t('tap_to_play'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(AppStrings.t('settings')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leaderboard() {
    return Container(
      width: math.min(320.0, MediaQuery.sizeOf(context).width - 32),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.t('best_scores'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: cTeal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          if (_scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                AppStrings.t('no_scores'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            )
          else
            ...List<Widget>.generate(_scores.length, (int i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 15),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _scores[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                    ),
                    Text(
                      '${_scores[i].score}',
                      style: const TextStyle(
                        color: cGold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _crashedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppStrings.t('crashed'),
                style: const TextStyle(
                  color: cRed,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              if (_isNewBest) ...<Widget>[
                Text(
                  AppStrings.t('new_best_bang'),
                  style: const TextStyle(
                    color: cGold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                AppStrings
                    .t('score_best_line')
                    .replaceFirst('%s', '${_score.round()}')
                    .replaceFirst('%s', '$_best'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
