import 'package:flutter_test/flutter_test.dart';
import 'package:towerdefense/engine/td_engine.dart';
import 'package:towerdefense/services/settings_service.dart';
import 'package:towerdefense/theme/td_themes.dart';

void main() {
  test('profile encodes/decodes as one JSON string', () {
    final raw = TDSettings.encodeProfile('Wajiha');
    expect(TDSettings.decodeProfile(raw), 'Wajiha');
    // Legacy migration path.
    expect(TDSettings.decodeProfile(null, legacyName: '  '),
        TDSettings.defaultName);
    expect(TDSettings.decodeProfile('not-json'), TDSettings.defaultName);
  });

  test('12 themes exist, first 4 free', () {
    expect(TDThemes.all.length, greaterThanOrEqualTo(12));
    expect(TDThemes.freeThemeIds.length, 4);
    expect(TDThemes.isProTheme('meadow'), false);
    expect(TDThemes.isProTheme('volcano'), true);
  });

  test('8 tower styles and 8 enemy styles and 8 map styles', () {
    expect(TowerStyles.names.length, 8);
    expect(EnemyStyles.names.length, 8);
    expect(MapStyles.names.length, 8);
    expect(TowerStyles.isPro(3), false);
    expect(TowerStyles.isPro(4), true);
    expect(MapStyles.isPro(3), false);
    expect(MapStyles.isPro(4), true);
    expect(MapStyles.look(0).tufts, greaterThan(0));
    expect(MapStyles.look(2).tufts, 0); // Clean Cut: no tufts
  });

  test('engine boots in setup phase with difficulty resources', () {
    final e = TDEngine(
      config: const TDGameConfig(difficulty: 1, endless: false, seed: 42),
      onEvent: (_, [__]) {},
      isPro: false,
    );
    expect(e.phase, TDPhase.setup);
    expect(e.gold, 250);
    expect(e.lives, 15);
    expect(e.maxTowerLevel, 2);
    expect(e.unlockedTowerKinds.length, 4);
    e.dispose();
  });

  test('pro engine unlocks all tower kinds and level 3', () {
    final e = TDEngine(
      config: const TDGameConfig(difficulty: 2, endless: true, seed: 7),
      onEvent: (_, [__]) {},
      isPro: true,
    );
    expect(e.unlockedTowerKinds.length, 8);
    expect(e.maxTowerLevel, 3);
    e.dispose();
  });

  test('placement rules enforced', () {
    final e = TDEngine(
      config: const TDGameConfig(difficulty: 0, endless: false, seed: 1),
      onEvent: (_, [__]) {},
      isPro: false,
    );
    // Road cell rejected.
    expect(e.placeTower(3, 1, 'arrow'), false);
    // Setup phase rejected.
    expect(e.placeTower(0, 0, 'arrow'), false);
    e.dispose();
  });

  test('path cells detected correctly', () {
    final e = TDEngine(
      config: const TDGameConfig(difficulty: 0, endless: false, seed: 1),
      onEvent: (_, [__]) {},
      isPro: false,
    );
    expect(e.cellOnPath(3, 1), true);
    expect(e.cellOnPath(0, 0), false);
    expect(e.posAt(0).dx, greaterThan(0));
    e.dispose();
  });

  test('breach at zero lives defeats without list crash', () {
    // Regression: _defeat() used to clear creeps while _simulate() iterated
    // the live list — a ConcurrentModificationError mid-battle. Driving the
    // sim deterministically through debugTick must reach defeat cleanly.
    final events = <TDEvent>[];
    final e = TDEngine(
      config: const TDGameConfig(difficulty: 1, endless: false, seed: 9),
      onEvent: (ev, [__]) => events.add(ev),
      isPro: false,
    );
    e.startGame();
    e.startWaveNow();
    expect(e.phase, TDPhase.waveActive);
    e.lives = 1;
    // A fast creep right at the gate: breaches on the first tick.
    e.creeps.add(Creep(
        id: 999,
        kind: 'walker',
        dist: e.pathLen - 0.001,
        hp: 1000,
        speed: 50,
        reward: 0,
        dmg: 5,
        wobble: 0));
    for (int i = 0; i < 10; i++) {
      e.debugTick();
    }
    expect(e.phase, TDPhase.defeat);
    expect(events, contains(TDEvent.breached));
    expect(events, contains(TDEvent.defeat));
    expect(e.lives, 0);
    e.dispose();
  });

  test('ballista pierce defers bolts without list crash', () {
    // Regression: the pierce branch added to [bolts] while _simulate()
    // iterated it — a ConcurrentModificationError on every pierce hit.
    final e = TDEngine(
      config: const TDGameConfig(difficulty: 1, endless: false, seed: 3),
      onEvent: (_, [__]) {},
      isPro: true,
    );
    e.startGame();
    e.startWaveNow();
    e.gold = 10000;
    expect(e.placeTower(0, 0, 'ballista'), true);
    e.creeps.add(Creep(
        id: 1,
        kind: 'walker',
        dist: 0.5,
        hp: 500,
        speed: 0.01,
        reward: 0,
        dmg: 1,
        wobble: 0));
    e.creeps.add(Creep(
        id: 2,
        kind: 'walker',
        dist: 0.6,
        hp: 500,
        speed: 0.01,
        reward: 0,
        dmg: 1,
        wobble: 0));
    for (int i = 0; i < 120; i++) {
      e.debugTick();
    }
    // No throw; the engine is still simulating or the wave progressed.
    expect(
        e.phase == TDPhase.waveActive || e.phase == TDPhase.waveClear, true);
    e.dispose();
  });
}
