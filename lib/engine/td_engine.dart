import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Tower Defense game engine.
///
/// The engine owns ALL game state and phases — the UI is a dumb renderer
/// plus input relay. No stuck states by construction:
/// - Every phase transition goes through [_setPhase]; each phase has exactly
///   one legal forward action, audited by [_audit].
/// - A watchdog timer runs [_audit] every 3s and repairs any phase found
///   without live work pending (missed timer, completed wave not noticed,
///   intro countdown elapsed, lives exhausted).
/// - The single game-loop timer is engine-owned; if it ever dies, the
///   watchdog restarts it.
///
/// Deterministic: all randomness comes from a seeded [Random], so a given
/// seed + inputs always replays the same battle.

// ------------------------------------------------------------------ phases
enum TDPhase {
  setup, // configured, waiting for the player to press start
  waveIntro, // banner countdown before a wave spawns
  waveActive, // spawning and/or fighting
  waveClear, // wave finished, rewards banked, waiting for next wave
  paused, // app paused / user paused; remembers [prePause]
  victory, // campaign complete
  defeat, // lives exhausted
}

// ------------------------------------------------------------------ config
class TDGameConfig {
  final int difficulty; // 0 recruit, 1 defender, 2 legend
  final bool endless;
  final int seed;
  const TDGameConfig(
      {required this.difficulty, required this.endless, required this.seed});
}

// ------------------------------------------------------------------ specs
/// Playable tower kinds. Free: arrow, cannon, frost, tesla. Pro unlocks
/// sniper, mortar, venom, ballista.
class TowerKinds {
  static const List<String> freeIds = ['arrow', 'cannon', 'frost', 'tesla'];
  static const List<String> proIds = ['sniper', 'mortar', 'venom', 'ballista'];
  static List<String> get allIds => [...freeIds, ...proIds];
  static bool isProKind(String id) => proIds.contains(id);

  static const Map<String, Map<String, dynamic>> specs = {
    'arrow': {
      'name': 'Arrow Tower',
      'cost': 50,
      'range': 2.6,
      'dmg': 10.0,
      'rate': 2.0,
      'projSpeed': 12.0,
    },
    'cannon': {
      'name': 'Cannon',
      'cost': 120,
      'range': 2.4,
      'dmg': 46.0,
      'rate': 0.7,
      'splash': 1.2,
      'projSpeed': 9.0,
    },
    'frost': {
      'name': 'Frost Tower',
      'cost': 90,
      'range': 2.2,
      'dmg': 5.0,
      'rate': 1.4,
      'slow': 0.5,
      'slowDur': 2.5,
      'projSpeed': 10.0,
    },
    'tesla': {
      'name': 'Tesla Coil',
      'cost': 150,
      'range': 2.8,
      'dmg': 14.0,
      'rate': 1.1,
      'chain': 2,
      'projSpeed': 30.0, // instant-ish arc
    },
    'sniper': {
      'name': 'Sniper Nest',
      'cost': 200,
      'range': 5.2,
      'dmg': 95.0,
      'rate': 0.5,
      'projSpeed': 26.0,
    },
    'mortar': {
      'name': 'Mortar',
      'cost': 260,
      'range': 3.4,
      'dmg': 75.0,
      'rate': 0.45,
      'splash': 2.0,
      'projSpeed': 7.0,
    },
    'venom': {
      'name': 'Venom Spitter',
      'cost': 180,
      'range': 2.4,
      'dmg': 8.0,
      'rate': 1.2,
      'poison': 6.0, // dps
      'poisonDur': 4.0,
      'projSpeed': 11.0,
    },
    'ballista': {
      'name': 'Ballista',
      'cost': 220,
      'range': 3.4,
      'dmg': 42.0,
      'rate': 1.0,
      'pierce': 3,
      'projSpeed': 16.0,
    },
  };
}

/// Creep archetypes unlocked as waves progress.
class CreepKinds {
  static const List<String> ids = [
    'walker',
    'runner',
    'swarm',
    'brute',
    'shield',
    'boss',
  ];
}

// ------------------------------------------------------------------ events
/// Engine -> UI events (SFX, narration, banners). The UI never guesses.
enum TDEvent {
  waveIntro,
  waveStart,
  waveCleared,
  towerPlaced,
  towerUpgraded,
  towerSold,
  creepDown,
  breached,
  victory,
  defeat,
  invalid, // illegal placement / action — UI plays the error sound
  sfx, // data is a String: 'shoot' | 'cannon' | 'frost' | 'zap'
}

// ------------------------------------------------------------------ model
class Creep {
  final int id;
  final String kind;
  double dist; // distance along path
  double hp;
  final double maxHp;
  double speed;
  final int reward;
  final int dmg; // lives lost on breach
  double slowT = 0;
  double slowFactor = 1.0;
  double poisonDps = 0;
  double poisonT = 0;
  double armor = 0; // fraction of damage ignored
  double wobble; // animation phase
  double deathT = -1; // >= 0 while death-poof anim plays

  Creep({
    required this.id,
    required this.kind,
    required this.dist,
    required this.hp,
    required this.speed,
    required this.reward,
    required this.dmg,
    required this.wobble,
  }) : maxHp = hp;
}

class Tower {
  final int id;
  final int col, row;
  final String kind;
  int level = 1; // 1..2 free, 1..3 pro
  int invested;
  double cooldown = 0;
  double angle = 0;
  double buildT = 0.45; // placement pop-in animation timer
  double upgradeFlash = 0; // upgrade sparkle timer

  Tower(
      {required this.id,
      required this.col,
      required this.row,
      required this.kind,
      required this.invested});
}

class Bolt {
  final String kind; // tower kind that fired
  double x, y;
  int targetId;
  double dmg;
  double splash;
  double slow;
  double slowDur;
  double poisonDps;
  double poisonDur;
  int pierce;
  int chain;
  List<int> hitIds = [];

  Bolt({
    required this.kind,
    required this.x,
    required this.y,
    required this.targetId,
    required this.dmg,
    this.splash = 0,
    this.slow = 0,
    this.slowDur = 0,
    this.poisonDps = 0,
    this.poisonDur = 0,
    this.pierce = 1,
    this.chain = 0,
  });
}

// ================================================================== engine
class TDEngine extends ChangeNotifier {
  static const cols = 9, rows = 9;
  static const campaignWaves = 30;
  static const introSecs = 2.2;

  /// Waypoints in cell coordinates.
  static const path = [
    [0, 1],
    [7, 1],
    [7, 4],
    [2, 4],
    [2, 7],
    [8, 7],
  ];

  final TDGameConfig config;
  final void Function(TDEvent event, [dynamic data]) onEvent;
  final bool isPro;

  late final Random rnd;
  TDPhase phase = TDPhase.setup;
  TDPhase _prePause = TDPhase.setup;

  int gold = 0;
  int lives = 0;
  int wave = 0;
  int kills = 0;
  int leaked = 0;
  int interestEarned = 0;

  final List<Creep> creeps = [];
  final List<Tower> towers = [];
  final List<Bolt> bolts = [];
  final List<Bolt> _pendingBolts = [];

  int _nextCreepId = 1;
  int _nextTowerId = 1;

  // Wave spawning state.
  final List<String> _spawnQueue = [];
  double _spawnGap = 0.8;
  double _spawnT = 0;
  double _introT = 0;
  double _clearT = 0; // waveClear banner timer before phase settles

  // Difficulty multipliers.
  late final double hpMul;
  late final double speedMul;
  late final double rewardMul;

  Timer? _loop;
  Timer? _watchdog;
  bool _disposed = false;

  late List<double> segLens;
  late double pathLen;

  TDEngine({
    required this.config,
    required this.onEvent,
    required this.isPro,
  }) {
    rnd = Random(config.seed);
    segLens = [];
    for (int i = 0; i < path.length - 1; i++) {
      segLens.add(
          ((path[i + 1][0] - path[i][0]).abs() + (path[i + 1][1] - path[i][1]).abs())
              .toDouble());
    }
    pathLen = segLens.fold(0.0, (a, b) => a + b);

    switch (config.difficulty) {
      case 0: // Recruit
        hpMul = 0.8;
        speedMul = 0.9;
        rewardMul = 1.0;
        gold = 300;
        lives = 20;
      case 2: // Legend
        hpMul = 1.35;
        speedMul = 1.1;
        rewardMul = 1.25;
        gold = 220;
        lives = 12;
      default: // Defender
        hpMul = 1.0;
        speedMul = 1.0;
        rewardMul = 1.0;
        gold = 250;
        lives = 15;
    }
    if (config.endless) {
      lives += 5;
      gold += 50;
    }

    _loop = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _audit());
  }

  int get maxWaves => config.endless ? 999999 : campaignWaves;
  int get maxTowerLevel => isPro ? 3 : 2;
  List<String> get unlockedTowerKinds => isPro
      ? TowerKinds.allIds
      : TowerKinds.freeIds;

  // ------------------------------------------------------------ public API
  void startGame() {
    if (phase != TDPhase.setup) return;
    onEvent(TDEvent.waveIntro);
    beginWaveIntro();
    notifyListeners();
  }

  void beginWaveIntro() {
    if (phase != TDPhase.setup && phase != TDPhase.waveClear) return;
    _setPhase(TDPhase.waveIntro);
    _introT = introSecs;
    notifyListeners();
  }

  void startWaveNow() {
    if (phase != TDPhase.waveIntro) return;
    _beginSpawning();
  }

  void pauseGame() {
    if (phase == TDPhase.paused ||
        phase == TDPhase.victory ||
        phase == TDPhase.defeat ||
        phase == TDPhase.setup) {
      return;
    }
    _prePause = phase;
    _setPhase(TDPhase.paused);
    notifyListeners();
  }

  void resumeGame() {
    if (phase != TDPhase.paused) return;
    _setPhase(_prePause);
    notifyListeners();
  }

  bool cellOnPath(int c, int r) {
    for (int i = 0; i < path.length - 1; i++) {
      final c0 = path[i][0], r0 = path[i][1];
      final c1 = path[i + 1][0], r1 = path[i + 1][1];
      if (c >= min(c0, c1) &&
          c <= max(c0, c1) &&
          r >= min(r0, r1) &&
          r <= max(r0, r1)) {
        return true;
      }
    }
    return false;
  }

  bool towerAt(int c, int r) => towers.any((t) => t.col == c && t.row == r);

  Tower? towerAtCell(int c, int r) {
    for (final t in towers) {
      if (t.col == c && t.row == r) return t;
    }
    return null;
  }

  int towerCost(String kind) => TowerKinds.specs[kind]!['cost'] as int;

  bool canPlace(String kind) =>
      (TowerKinds.specs[kind]!['cost'] as int) <= gold;

  /// Returns true if the tower was placed.
  bool placeTower(int c, int r, String kind) {
    if (phase == TDPhase.paused ||
        phase == TDPhase.victory ||
        phase == TDPhase.defeat ||
        phase == TDPhase.setup) {
      onEvent(TDEvent.invalid);
      return false;
    }
    if (!unlockedTowerKinds.contains(kind)) {
      onEvent(TDEvent.invalid);
      return false;
    }
    if (cellOnPath(c, r) || towerAt(c, r)) {
      onEvent(TDEvent.invalid);
      return false;
    }
    final cost = towerCost(kind);
    if (gold < cost) return false;
    gold -= cost;
    towers.add(Tower(
        id: _nextTowerId++, col: c, row: r, kind: kind, invested: cost));
    onEvent(TDEvent.towerPlaced);
    notifyListeners();
    return true;
  }

  int upgradeCost(Tower t) => (t.invested * 0.8).round();

  bool canUpgrade(Tower t) =>
      t.level < maxTowerLevel && gold >= upgradeCost(t);

  bool upgradeTower(Tower t) {
    if (!towers.contains(t)) return false;
    if (t.level >= maxTowerLevel) return false;
    final cost = upgradeCost(t);
    if (gold < cost) return false;
    gold -= cost;
    t.invested += cost;
    t.level++;
    t.upgradeFlash = 0.8;
    onEvent(TDEvent.towerUpgraded);
    notifyListeners();
    return true;
  }

  int sellValue(Tower t) => (t.invested * 0.7).round();

  bool sellTower(Tower t) {
    if (!towers.remove(t)) return false;
    gold += sellValue(t);
    onEvent(TDEvent.towerSold);
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------- phase machinery
  void _setPhase(TDPhase p) {
    phase = p;
  }

  void _beginSpawning() {
    wave++;
    _spawnQueue
      ..clear()
      ..addAll(_composeWave(wave));
    _spawnGap = max(0.22, 0.85 - wave * 0.022);
    _spawnT = 0.4;
    _setPhase(TDPhase.waveActive);
    onEvent(TDEvent.waveStart, wave);
    notifyListeners();
  }

  List<String> _composeWave(int w) {
    final q = <String>[];
    final bossWave = w % 5 == 0;
    if (bossWave) {
      q.add('boss');
      final escorts = min(4 + w ~/ 2, 14);
      for (int i = 0; i < escorts; i++) {
        q.add(i % 3 == 0 ? 'brute' : 'walker');
      }
      if (w >= 15) q.add('boss');
    } else {
      int count = 6 + (w * 1.6).round();
      // Difficulty shifts the count a little.
      count = (count * (config.difficulty == 0 ? 0.85 : 1.0)).round();
      for (int i = 0; i < count; i++) {
        final roll = rnd.nextDouble();
        if (w >= 8 && roll < 0.14) {
          q.add('shield');
        } else if (w >= 5 && roll < 0.30) {
          q.add('brute');
        } else if (w >= 3 && roll < 0.52) {
          q.add(i % 4 == 0 ? 'swarm' : 'runner');
        } else {
          q.add(roll < 0.75 ? 'walker' : 'runner');
        }
      }
    }
    return q;
  }

  void _spawnNext() {
    if (_spawnQueue.isEmpty) return;
    final kind = _spawnQueue.removeAt(0);
    final w = wave;
    final growth = pow(1.16, w).toDouble();
    late double hp;
    late double speed;
    late int reward;
    late int dmg;
    late double armor;
    switch (kind) {
      case 'runner':
        hp = 16 * growth;
        speed = 1.25;
        reward = 5;
        dmg = 1;
        armor = 0;
      case 'swarm':
        hp = 8 * growth;
        speed = 1.15;
        reward = 3;
        dmg = 1;
        armor = 0;
      case 'brute':
        hp = 55 * growth;
        speed = 0.62;
        reward = 14;
        dmg = 2;
        armor = 0;
      case 'shield':
        hp = 70 * growth;
        speed = 0.7;
        reward = 18;
        dmg = 2;
        armor = 0.45;
      case 'boss':
        hp = 320 * growth;
        speed = 0.5;
        reward = 120;
        dmg = 5;
        armor = 0.2;
      default: // walker
        hp = 26 * growth;
        speed = 0.85;
        reward = 7;
        dmg = 1;
        armor = 0;
    }
    hp *= hpMul;
    speed *= speedMul * (0.94 + rnd.nextDouble() * 0.12);
    reward = max(1, (reward * rewardMul).round());
    creeps.add(Creep(
      id: _nextCreepId++,
      kind: kind,
      dist: -0.6 - rnd.nextDouble() * 0.5,
      hp: hp,
      speed: speed,
      reward: reward,
      dmg: dmg,
      wobble: rnd.nextDouble() * pi * 2,
    )..armor = armor);
  }

  /// Test hook: drive one 20Hz simulation step synchronously.
  @visibleForTesting
  void debugTick() => _tick();

  /// Engine tick: 20Hz simulation step.
  void _tick() {
    if (_disposed) return;
    const dt = 0.05;
    switch (phase) {
      case TDPhase.setup:
      case TDPhase.paused:
      case TDPhase.victory:
      case TDPhase.defeat:
        return; // frozen by construction
      case TDPhase.waveIntro:
        _introT -= dt;
        if (_introT <= 0) _beginSpawning();
        notifyListeners();
      case TDPhase.waveActive:
        _simulate(dt);
        notifyListeners();
      case TDPhase.waveClear:
        _clearT -= dt;
        // Small breather banner, then settle into "ready" — the player
        // starts the next wave when they want.
        if (_clearT <= 0) {
          // stays waveClear; player presses start. Nothing to do.
        }
        notifyListeners();
    }
  }

  void _simulate(double dt) {
    // Spawning.
    if (_spawnQueue.isNotEmpty) {
      _spawnT -= dt;
      if (_spawnT <= 0) {
        _spawnNext();
        _spawnT = _spawnGap;
      }
    }
    // Creeps move / poison / breach.
    // Iterate a snapshot: _breach() can trigger _defeat(), which clears the
    // lists mid-iteration — iterating the live list would throw.
    for (final c in creeps.toList()) {
      if (c.deathT >= 0) {
        c.deathT -= dt;
        continue;
      }
      if (c.poisonT > 0) {
        c.poisonT -= dt;
        c.hp -= c.poisonDps * dt;
      }
      if (c.slowT > 0) c.slowT -= dt;
      final slowMul = c.slowT > 0 ? c.slowFactor : 1.0;
      c.dist += c.speed * slowMul * dt;
      c.wobble += dt * 6;
      if (c.hp <= 0) {
        _killCreep(c);
      } else if (c.dist >= pathLen) {
        _breach(c);
        if (phase != TDPhase.waveActive) return; // defeat may have fired
      }
    }
    // Towers fire.
    for (final tw in towers) {
      if (tw.buildT > 0) tw.buildT -= dt;
      if (tw.upgradeFlash > 0) tw.upgradeFlash -= dt;
      tw.cooldown -= dt;
      final s = TowerKinds.specs[tw.kind]!;
      final range = (s['range'] as double) + (tw.level - 1) * 0.35;
      final tp = _cellCenter(tw.col, tw.row);
      final target = _pickTarget(tp, range);
      if (target != null) {
        final p = posAt(target.dist);
        tw.angle = atan2(p.dy - tp.dy, p.dx - tp.dx);
        if (tw.cooldown <= 0) {
          tw.cooldown = 1 / (s['rate'] as double);
          _fire(tw, s, target, tp);
        }
      }
    }
    // Bolts fly. New bolts spawned mid-flight (ballista pierce) are
    // deferred — adding to [bolts] while iterating it would throw.
    _pendingBolts.clear();
    final spent = <Bolt>[];
    for (final b in bolts.toList()) {
      final target = _creepById(b.targetId);
      if (target == null || target.deathT >= 0 || target.hp <= 0) {
        spent.add(b);
        continue;
      }
      final p = posAt(target.dist);
      final d = (p - Offset(b.x, b.y)).distance;
      if (d < 0.22) {
        _impact(b, target, p);
        spent.add(b);
      } else {
        final step = (TowerKinds.specs[b.kind]!['projSpeed'] as double) * dt;
        b.x += (p.dx - b.x) / d * step;
        b.y += (p.dy - b.y) / d * step;
      }
    }
    bolts.removeWhere(spent.contains);
    bolts.addAll(_pendingBolts);
    _pendingBolts.clear();
    // Sweep finished death anims.
    creeps.removeWhere((c) => c.deathT >= 0 && c.deathT <= 0);
    // Wave is done when nothing is left to spawn, no creeps remain alive or
    // mid-animation, and no bolts are still flying.
    if (_spawnQueue.isEmpty && creeps.isEmpty && bolts.isEmpty) {
      _completeWave();
    }
  }

  Creep? _creepById(int id) {
    for (final c in creeps) {
      if (c.id == id) return c;
    }
    return null;
  }

  Creep? _pickTarget(Offset tp, double range) {
    Creep? best;
    double bestD = -1;
    for (final c in creeps) {
      if (c.hp <= 0 || c.deathT >= 0 || c.dist < 0) continue;
      final p = posAt(c.dist);
      if ((p - tp).distance <= range && c.dist > bestD) {
        bestD = c.dist;
        best = c;
      }
    }
    return best;
  }

  void _fire(Tower tw, Map<String, dynamic> s, Creep target, Offset tp) {
    final lvlMul = tw.level == 1 ? 1.0 : (tw.level == 2 ? 1.9 : 2.8);
    final dmg = (s['dmg'] as double) * lvlMul;
    bolts.add(Bolt(
      kind: tw.kind,
      x: tp.dx,
      y: tp.dy,
      targetId: target.id,
      dmg: dmg,
      splash: (s['splash'] as double?) ?? 0,
      slow: (s['slow'] as double?) ?? 0,
      slowDur: (s['slowDur'] as double?) ?? 0,
      poisonDps: ((s['poison'] as double?) ?? 0) * lvlMul,
      poisonDur: (s['poisonDur'] as double?) ?? 0,
      pierce: (s['pierce'] as int?) ?? 1,
      chain: (s['chain'] as int?) ?? 0,
    ));
    switch (tw.kind) {
      case 'cannon':
      case 'mortar':
        onEvent(TDEvent.sfx, 'cannon');
      case 'frost':
        onEvent(TDEvent.sfx, 'frost');
      case 'tesla':
        onEvent(TDEvent.sfx, 'zap');
      default:
        onEvent(TDEvent.sfx, 'shoot');
    }
  }

  void _impact(Bolt b, Creep target, Offset p) {
    void damage(Creep c, double dmg) {
      if (c.deathT >= 0) return;
      final dealt = dmg * (1 - c.armor);
      c.hp -= dealt;
      if (b.poisonDps > 0) {
        c.poisonDps = max(c.poisonDps, b.poisonDps);
        c.poisonT = b.poisonDur;
      }
      if (c.hp <= 0) _killCreep(c);
    }

    if (b.splash > 0) {
      for (final c in creeps.toList()) {
        if (c.deathT >= 0 || c.dist < 0) continue;
        if ((posAt(c.dist) - p).distance <= b.splash) damage(c, b.dmg);
      }
    } else if (b.chain > 0) {
      damage(target, b.dmg);
      // Chain to nearest other creeps.
      Creep? current = target;
      var remaining = b.chain;
      final chained = <int>{target.id};
      while (remaining > 0 && current != null) {
        final cp = posAt(current.dist);
        Creep? next;
        double nd = 1e9;
        for (final c in creeps) {
          if (c.deathT >= 0 || chained.contains(c.id) || c.dist < 0) continue;
          final d = (posAt(c.dist) - cp).distance;
          if (d < 2.2 && d < nd) {
            nd = d;
            next = c;
          }
        }
        if (next == null) break;
        chained.add(next.id);
        damage(next, b.dmg * 0.7);
        current = next;
        remaining--;
      }
    } else {
      damage(target, b.dmg);
      if (b.slow > 0 && target.deathT < 0) {
        target.slowT = b.slowDur;
        target.slowFactor = 1 - b.slow;
      }
      if (b.pierce > 1 && target.deathT < 0) {
        // Ballista bolt punches through: re-target the next creep in line.
        // Deferred — the bolt list is being iterated right now.
        final next = _pickTarget(Offset(b.x, b.y), 1.2);
        if (next != null && next.id != target.id) {
          _pendingBolts.add(Bolt(
            kind: b.kind,
            x: b.x,
            y: b.y,
            targetId: next.id,
            dmg: b.dmg * 0.8,
            pierce: b.pierce - 1,
          ));
        }
      }
    }
  }

  void _killCreep(Creep c) {
    if (c.deathT >= 0) return;
    c.deathT = 0.35; // death-poof animation plays, then swept
    c.hp = 0;
    gold += c.reward;
    kills++;
    onEvent(TDEvent.creepDown, c.reward);
  }

  void _breach(Creep c) {
    c.deathT = 0.0; // removed immediately, no reward
    c.hp = -1;
    lives -= c.dmg;
    leaked++;
    onEvent(TDEvent.breached, c.dmg);
    if (lives <= 0) {
      lives = 0;
      _defeat();
    }
  }

  void _completeWave() {
    // Wave-clear bonus: gold scales with wave; small heal every 5 waves.
    final bonus = 25 + wave * 3;
    gold += bonus;
    interestEarned += bonus;
    if (wave % 5 == 0) lives = min(lives + 2, 30);
    _clearT = 1.6;
    _setPhase(TDPhase.waveClear);
    onEvent(TDEvent.waveCleared, bonus);
    if (!config.endless && wave >= campaignWaves) {
      _victory();
      return;
    }
    notifyListeners();
  }

  void _victory() {
    _setPhase(TDPhase.victory);
    onEvent(TDEvent.victory);
    notifyListeners();
  }

  void _defeat() {
    _setPhase(TDPhase.defeat);
    creeps.clear();
    bolts.clear();
    onEvent(TDEvent.defeat);
    notifyListeners();
  }

  /// Watchdog: repairs any phase found without live work pending.
  /// Stuck states are impossible by construction — this is the belt.
  void _audit() {
    if (_disposed) return;
    // 1. Loop timer must be alive while the game is live.
    final live = phase == TDPhase.waveIntro ||
        phase == TDPhase.waveActive ||
        phase == TDPhase.waveClear;
    if (live && (_loop == null || !_loop!.isActive)) {
      _loop = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    }
    // 2. Intro countdown must have a live timer; force through if stuck.
    if (phase == TDPhase.waveIntro && _introT <= 0) {
      _beginSpawning();
    }
    // 3. Active wave with nothing left to do must complete.
    if (phase == TDPhase.waveActive &&
        _spawnQueue.isEmpty &&
        creeps.isEmpty &&
        bolts.isEmpty) {
      _completeWave();
    }
    // 4. Lives exhausted but no defeat yet.
    if (lives <= 0 &&
        phase != TDPhase.defeat &&
        phase != TDPhase.victory &&
        phase != TDPhase.setup) {
      _defeat();
    }
    // 5. Campaign finished but no victory yet.
    if (!config.endless &&
        wave >= campaignWaves &&
        (phase == TDPhase.waveClear || phase == TDPhase.waveActive)) {
      if (phase == TDPhase.waveClear) _victory();
    }
    // 6. waveClear banner timer must eventually settle — player starts next.
    if (phase == TDPhase.waveClear && _clearT <= -30) {
      _clearT = 0; // banner long done; phase stays until player acts
    }
  }

  // ---------------------------------------------------------------- helpers
  Offset _cellCenter(int c, int r) => Offset(c + 0.5, r + 0.5);

  Offset posAt(double d) {
    double r = d;
    for (int i = 0; i < segLens.length; i++) {
      if (r <= segLens[i] || i == segLens.length - 1) {
        final t = segLens[i] <= 0 ? 0 : (r / segLens[i]).clamp(0.0, 1.0);
        return Offset(
          path[i][0] + (path[i + 1][0] - path[i][0]) * t + 0.5,
          path[i][1] + (path[i + 1][1] - path[i][1]) * t + 0.5,
        );
      }
      r -= segLens[i];
    }
    return Offset(path.last[0] + 0.5, path.last[1] + 0.5);
  }

  @override
  void dispose() {
    _disposed = true;
    _loop?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}
