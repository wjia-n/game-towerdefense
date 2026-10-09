import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/td_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/td_themes.dart';
import 'pro_screen.dart';

/// Gameplay screen: renders the engine, relays input, plays event SFX.
class GameScreen extends StatefulWidget {
  final TDAudio audio;
  final TDSettings settings;
  final StoreService store;
  final TDGameConfig config;
  const GameScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store,
      required this.config});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  late final TDEngine engine;
  int? selC, selR; // selected cell
  Tower? selTower;
  String? banner; // transient narration banner
  bool _ended = false;
  bool _reviewAsked = false;

  TDThemeDef get t =>
      TDThemes.byId(widget.settings.themeId, custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = TDEngine(
      config: widget.config,
      isPro: widget.settings.isPro,
      onEvent: _onEngineEvent,
    );
    widget.audio.startGameMusic();
    // Kick off the first wave intro after a beat.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && engine.phase == TDPhase.setup) engine.startGame();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      engine.pauseGame();
    }
  }

  void _onEngineEvent(TDEvent event, [dynamic data]) {
    if (!mounted) return;
    final a = widget.audio;
    switch (event) {
      case TDEvent.waveIntro:
        setState(() => banner = 'Get ready…');
      case TDEvent.waveStart:
        a.waveHorn();
        setState(
            () => banner = '🌊 Wave ${data as int} — they\'re coming!');
        _clearBannerSoon();
      case TDEvent.waveCleared:
        a.win();
        setState(() => banner = '✅ Wave cleared! +${data}g bonus');
        _clearBannerSoon();
      case TDEvent.towerPlaced:
        a.place();
      case TDEvent.towerUpgraded:
        a.upgrade();
      case TDEvent.towerSold:
        a.sell();
      case TDEvent.creepDown:
        a.gold();
      case TDEvent.breached:
        a.breach();
        setState(() => banner = '💥 Breach! -${data} ❤️');
        _clearBannerSoon();
      case TDEvent.invalid:
        a.invalid();
      case TDEvent.sfx:
        switch (data as String) {
          case 'cannon':
            a.cannon();
          case 'frost':
            a.frost();
          case 'zap':
            a.zap();
          default:
            a.shoot();
        }
      case TDEvent.victory:
        a.win();
        _finish(true);
      case TDEvent.defeat:
        a.lose();
        _finish(false);
    }
  }

  void _clearBannerSoon() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => banner = null);
    });
  }

  Future<void> _finish(bool won) async {
    if (_ended) return;
    _ended = true;
    await widget.settings.recordGame(
      won: won,
      wave: engine.wave,
      endless: widget.config.endless,
      kills: engine.kills,
    );
    if (!mounted) return;
    // Sensible review moment: campaign victory, or a strong endless run.
    if (!_reviewAsked &&
        (won || (widget.config.endless && engine.wave >= 10))) {
      _reviewAsked = true;
      try {
        if (await InAppReview.instance.isAvailable()) {
          await InAppReview.instance.requestReview();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EndDialog(
        t: t,
        won: won,
        endless: widget.config.endless,
        wave: engine.wave,
        kills: engine.kills,
        best: widget.config.endless
            ? widget.settings.bestEndless
            : widget.settings.bestWave,
        audio: widget.audio,
        onReplay: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                audio: widget.audio,
                settings: widget.settings,
                store: widget.store,
                config: TDGameConfig(
                  difficulty: widget.settings.difficulty,
                  endless: widget.config.endless,
                  seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
                ),
              ),
            ),
          );
        },
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _onTapCell(int c, int r) {
    if (engine.phase == TDPhase.paused ||
        engine.phase == TDPhase.victory ||
        engine.phase == TDPhase.defeat) {
      return;
    }
    final tw = engine.towerAtCell(c, r);
    setState(() {
      selC = c;
      selR = r;
      selTower = tw;
    });
    widget.audio.click();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (_, _) => Scaffold(
        backgroundColor: t.card,
        appBar: AppBar(
          backgroundColor: t.card,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.pause, color: t.text),
            onPressed: () {
              widget.audio.click();
              engine.pauseGame();
              _pauseMenu();
            },
          ),
          title: Text(
            widget.config.endless
                ? 'Endless Siege'
                : 'Wave ${engine.wave}/${TDEngine.campaignWaves}',
            style: TDStyle.display(18, t),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                  widget.settings.musicOn ? Icons.music_note : Icons.music_off,
                  color: t.text),
              onPressed: () {
                final v = !widget.settings.musicOn;
                widget.settings.setMusic(v);
                widget.audio.configure(
                    musicOn: v,
                    sfxOn: widget.settings.sfxOn,
                    volume: widget.settings.volume);
                if (v) {
                  widget.audio.startGameMusic();
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _hud(),
              if (banner != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.accent),
                  ),
                  child: Text(banner!,
                      textAlign: TextAlign.center,
                      style: TDStyle.label(13, t)),
                ),
              Expanded(child: _board()),
              _bottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _hudChip('💰', '${engine.gold}'),
          _hudChip('❤️', '${engine.lives}'),
          _hudChip('👹', '${engine.kills}'),
          _hudChip(
              '🛡️',
              widget.settings.playerName.length > 10
                  ? '${widget.settings.playerName.substring(0, 10)}…'
                  : widget.settings.playerName),
        ],
      ),
    );
  }

  Widget _hudChip(String emoji, String v) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.cardDeep.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$emoji $v',
            style: TDStyle.label(13, t)),
      );

  Widget _board() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(builder: (ctx, box) {
        final cell = min(box.maxWidth / TDEngine.cols,
            box.maxHeight / TDEngine.rows);
        final w = cell * TDEngine.cols;
        final h = cell * TDEngine.rows;
        return Center(
          child: GestureDetector(
            onTapDown: (d) => _onTapCell(
              (d.localPosition.dx / cell).floor().clamp(0, TDEngine.cols - 1),
              (d.localPosition.dy / cell).floor().clamp(0, TDEngine.rows - 1),
            ),
            child: CustomPaint(
              size: Size(w, h),
              painter: _BoardPainter(
                theme: t,
                engine: engine,
                selC: selC,
                selR: selR,
                towerStyle: widget.settings.towerStyle,
                enemyStyle: widget.settings.enemyStyle,
                mapStyle: widget.settings.mapStyle,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _bottomPanel() {
    final theme = t;
    Widget content;
    if (selTower != null && engine.towers.contains(selTower)) {
      content = _towerPanel(theme, selTower!);
    } else if (selC != null &&
        selR != null &&
        !engine.cellOnPath(selC!, selR!) &&
        !engine.towerAt(selC!, selR!)) {
      content = _buildPanel(theme);
    } else if (engine.phase == TDPhase.waveIntro) {
      content = Text('🌊 Wave ${engine.wave + 1} incoming…',
          style: TDStyle.label(15, theme));
    } else if (engine.phase == TDPhase.waveClear) {
      content = ElevatedButton(
        style: TDStyle.primary(theme),
        onPressed: () {
          widget.audio.click();
          engine.beginWaveIntro();
          setState(() {
            selC = null;
            selR = null;
            selTower = null;
          });
        },
        child: Text(engine.wave >= TDEngine.campaignWaves && !widget.config.endless
            ? 'Done'
            : 'Start wave ${engine.wave + 1}  ⚔️'),
      );
    } else if (engine.phase == TDPhase.waveActive) {
      content = Text('Hold the line, ${widget.settings.playerName}!',
          style: TDStyle.label(14, theme, color: theme.muted));
    } else {
      content = const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accent.withValues(alpha: 0.5)),
      ),
      child: content,
    );
  }

  Widget _buildPanel(TDThemeDef theme) {
    final kinds = engine.unlockedTowerKinds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('BUILD TOWER', style: TDStyle.label(12, theme)),
        const SizedBox(height: 6),
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final id in kinds)
                _buildCard(theme, id),
              if (!widget.settings.isPro)
                GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                            audio: widget.audio,
                            settings: widget.settings,
                            store: widget.store)));
                  },
                  child: Container(
                    width: 92,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.accent, width: 1.5),
                    ),
                    child: Center(
                      child: Text('🔒\nMore\ntowers',
                          textAlign: TextAlign.center,
                          style: TDStyle.label(11, theme)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(TDThemeDef theme, String id) {
    final spec = TowerKinds.specs[id]!;
    final cost = spec['cost'] as int;
    final afford = engine.gold >= cost;
    return GestureDetector(
      onTap: afford && selC != null && selR != null
          ? () {
              final ok =
                  engine.placeTower(selC!, selR!, id);
              if (ok) {
                setState(() {
                  selTower = engine.towerAtCell(selC!, selR!);
                });
              }
            }
          : () => widget.audio.invalid(),
      child: Opacity(
        opacity: afford ? 1 : 0.45,
        child: Container(
          width: 92,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.accent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_towerEmoji(id),
                  style: const TextStyle(fontSize: 26)),
              Text(spec['name'] as String,
                  style: TDStyle.label(10, theme),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('💰$cost',
                  style: TDStyle.body(11, theme, color: theme.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _towerPanel(TDThemeDef theme, Tower tw) {
    final spec = TowerKinds.specs[tw.kind]!;
    final upCost = engine.upgradeCost(tw);
    final sellV = engine.sellValue(tw);
    final maxed = tw.level >= engine.maxTowerLevel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_towerEmoji(tw.kind),
                style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Text('${spec['name']}  •  Lv${tw.level}',
                style: TDStyle.display(16, theme)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!maxed)
              ElevatedButton(
                style: TDStyle.soft(theme),
                onPressed: engine.canUpgrade(tw)
                    ? () => engine.upgradeTower(tw)
                    : () => widget.audio.invalid(),
                child: Text('⬆️ Upgrade 💰$upCost',
                    style: TDStyle.label(12, theme)),
              )
            else
              Text('⭐ MAX', style: TDStyle.label(13, theme)),
            ElevatedButton(
              style: TDStyle.soft(theme),
              onPressed: () {
                engine.sellTower(tw);
                setState(() {
                  selTower = null;
                  selC = null;
                  selR = null;
                });
              },
              child: Text('💸 Sell 💰$sellV',
                  style: TDStyle.label(12, theme)),
            ),
            ElevatedButton(
              style: TDStyle.soft(theme),
              onPressed: () => setState(() {
                selTower = null;
                selC = null;
                selR = null;
              }),
              child: Text('✖️', style: TDStyle.label(12, theme)),
            ),
          ],
        ),
      ],
    );
  }

  String _towerEmoji(String id) => switch (id) {
        'arrow' => '🏹',
        'cannon' => '💣',
        'frost' => '❄️',
        'tesla' => '⚡',
        'sniper' => '🎯',
        'mortar' => '🚀',
        'venom' => '🧪',
        'ballista' => '🔱',
        _ => '🗼',
      };

  void _pauseMenu() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Paused', style: TDStyle.display(24, t)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: TDStyle.primary(t),
                onPressed: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                  engine.resumeGame();
                },
                child: const Text('▶️ Resume'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: TDStyle.soft(t),
                onPressed: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('🏳️ Give up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndDialog extends StatelessWidget {
  final TDThemeDef t;
  final bool won;
  final bool endless;
  final int wave;
  final int kills;
  final int best;
  final TDAudio audio;
  final VoidCallback onReplay;
  final VoidCallback onMenu;
  const _EndDialog(
      {required this.t,
      required this.won,
      required this.endless,
      required this.wave,
      required this.kills,
      required this.best,
      required this.audio,
      required this.onReplay,
      required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: t.card,
      title: Text(
        won ? '🏰 The castle stands!' : '💥 The castle fell…',
        style: TDStyle.display(24, t),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won
                ? 'All ${TDEngine.campaignWaves} waves repelled. Legendary defense!'
                : endless
                    ? 'You held for $wave waves. The horde never ends…'
                    : 'Overrun on wave $wave of ${TDEngine.campaignWaves}.',
            style: TDStyle.body(15, t),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text('👹 $kills creeps down   •   🏆 Best: $wave${endless ? '' : '/${TDEngine.campaignWaves}'}',
              style: TDStyle.label(13, t), textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            audio.click();
            onMenu();
          },
          child: Text('Menu', style: TDStyle.label(14, t)),
        ),
        ElevatedButton(
          style: TDStyle.primary(t),
          onPressed: () {
            audio.click();
            onReplay();
          },
          child: const Text('⚔️ Play again'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ painter
class _BoardPainter extends CustomPainter {
  final TDThemeDef theme;
  final TDEngine engine;
  final int? selC, selR;
  final int towerStyle;
  final int enemyStyle;
  final int mapStyle;
  _BoardPainter({
    required this.theme,
    required this.engine,
    required this.selC,
    required this.selR,
    required this.towerStyle,
    required this.enemyStyle,
    required this.mapStyle,
  });

  // Style palettes: cosmetic paint applied to towers / creeps.
  static const _towerPaints = [
    [0xFF9C6B3F, 0xFF6E4826], // Oakwood
    [0xFF7BA05B, 0xFF55703D], // Pinewood
    [0xFF9A9A9A, 0xFF6B6B6B], // Granite
    [0xFFD9B36A, 0xFFA5813F], // Sandstone
    [0xFF6E7B8A, 0xFF47505C], // Ironclad
    [0xFFB08D3E, 0xFF7E6428], // Royal Oak
    [0xFF6F8F5F, 0xFF4C6540], // Mossy Stone
    [0xFF3E3E4A, 0xFF23232B], // Obsidian
  ];
  static const _enemyPaints = [
    [0xFFB8452E, 0xFF7E2F1F], // Grubs
    [0xFF5E3F8A, 0xFF3E2A5C], // Beetles
    [0xFF7A9E2E, 0xFF546E1F], // Mud Blobs
    [0xFF8A7A6E, 0xFF5C5248], // Rockbits
    [0xFFD9A42B, 0xFF96701A], // Paper Lanterns
    [0xFF4A4A5C, 0xFF2C2C38], // Shadow Mites
    [0xFFD94E2B, 0xFF96331A], // Magma Pods
    [0xFF5EB8D9, 0xFF3E7E97], // Crystal Shards
  ];

  @override
  void paint(Canvas c, Size size) {
    final cell = size.width / TDEngine.cols;
    final look = MapStyles.look(mapStyle);
    final rnd = Random(1234); // stable grass tufts
    // Meadow: mowed checkerboard stripes, or a plain field on some styles.
    for (int r = 0; r < TDEngine.rows; r++) {
      for (int q = 0; q < TDEngine.cols; q++) {
        final base = look.plain || (q + r) % 2 == 0
            ? theme.grassLight
            : theme.grassDark;
        c.drawRect(
            Rect.fromLTWH(q * cell, r * cell, cell, cell),
            Paint()..color = base);
      }
    }
    // Worn patches beside the road.
    if (look.patches) {
      for (int i = 0; i < 12; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = rnd.nextDouble() * size.height;
        c.drawEllipse(
            Rect.fromCenter(
                center: Offset(x, y),
                width: cell * (0.5 + rnd.nextDouble() * 0.8),
                height: cell * (0.3 + rnd.nextDouble() * 0.5)),
            Paint()
              ..color =
                  theme.grassDark.withValues(alpha: 0.55));
      }
    }
    // Grass tufts.
    for (int i = 0; i < look.tufts; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      c.drawLine(
          Offset(x, y),
          Offset(x + 3, y - 6),
          Paint()
            ..color = theme.grassDark.withValues(alpha: 0.7)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
    // Little flowers.
    if (look.flowers) {
      for (int i = 0; i < 18; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = rnd.nextDouble() * size.height;
        c.drawCircle(Offset(x, y), 3.2,
            Paint()..color = theme.accent.withValues(alpha: 0.9));
        c.drawCircle(Offset(x, y), 1.4,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
    c.drawRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height,
            const Radius.circular(12)),
        Paint()
          ..color = theme.stoneDark.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    // Dirt road.
    final road = Paint()
      ..color = theme.roadLight
      ..strokeWidth = cell * 0.72 * look.roadWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = theme.roadDark
      ..strokeWidth = cell * 0.86 * look.roadWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Offset wp(int i) => Offset(
        (TDEngine.path[i][0] + 0.5) * cell,
        (TDEngine.path[i][1] + 0.5) * cell);
    if (look.edging) {
      final edging = Paint()
        ..color = theme.stone
        ..strokeWidth = cell * 0.98 * look.roadWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < TDEngine.path.length - 1; i++) {
        c.drawLine(wp(i), wp(i + 1), edging);
      }
    }
    for (int i = 0; i < TDEngine.path.length - 1; i++) {
      c.drawLine(wp(i), wp(i + 1), roadEdge);
    }
    for (int i = 0; i < TDEngine.path.length - 1; i++) {
      c.drawLine(wp(i), wp(i + 1), road);
    }
    // Pebbles on the path.
    if (look.pebbles) {
      for (int i = 0; i < 22; i++) {
        final seg = i % (TDEngine.path.length - 1);
        final f = rnd.nextDouble();
        final a = wp(seg);
        final b = wp(seg + 1);
        final off = (rnd.nextDouble() - 0.5) * cell * 0.4;
        c.drawCircle(
            Offset(a.dx + (b.dx - a.dx) * f + off,
                a.dy + (b.dy - a.dy) * f + off),
            2.6 + rnd.nextDouble() * 2.2,
            Paint()..color = theme.stone.withValues(alpha: 0.8));
      }
    }
    // Castle gate at the end of the road.
    final gate = wp(TDEngine.path.length - 1);
    c.drawCircle(gate, cell * 0.55, Paint()..color = theme.stoneDark);
    c.drawCircle(gate, cell * 0.42, Paint()..color = theme.stone);
    c.drawRect(
        Rect.fromCenter(
            center: gate, width: cell * 0.5, height: cell * 0.6),
        Paint()..color = theme.woodDark);
    // Spawn portal at the start.
    final spawn = wp(0);
    c.drawCircle(spawn, cell * 0.45,
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    c.drawCircle(
        spawn,
        cell * 0.45,
        Paint()
          ..color = theme.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    // Selection ring.
    if (selC != null && selR != null) {
      c.drawRRect(
          RRect.fromLTRBR(selC! * cell, selR! * cell,
                  (selC! + 1) * cell, (selR! + 1) * cell,
                  const Radius.circular(6)),
          Paint()..color = theme.accent.withValues(alpha: 0.35));
    }
    // Towers.
    for (final tw in engine.towers) {
      _drawTower(c, tw, cell);
    }
    // Creeps.
    for (final cr in engine.creeps) {
      _drawCreep(c, cr, cell);
    }
    // Bolts.
    for (final b in engine.bolts) {
      final col = switch (b.kind) {
        'frost' => const Color(0xFF7EC8E3),
        'tesla' => const Color(0xFFE8C83E),
        'cannon' || 'mortar' => const Color(0xFF5C5C5C),
        'venom' => const Color(0xFF7AC83E),
        _ => theme.accent,
      };
      c.drawCircle(Offset(b.x * cell, b.y * cell), max(3, cell * 0.09),
          Paint()..color = col);
      c.drawCircle(Offset(b.x * cell, b.y * cell), max(5, cell * 0.14),
          Paint()..color = col.withValues(alpha: 0.3));
    }
  }

  void _drawTower(Canvas c, Tower tw, double cell) {
    final o = Offset((tw.col + 0.5) * cell, (tw.row + 0.5) * cell);
    final paint = _towerPaints[towerStyle.clamp(0, 7)];
    final body = Color(paint[0]);
    final dark = Color(paint[1]);
    // Build pop-in scale.
    final s = tw.buildT > 0 ? (1 - tw.buildT / 0.45).clamp(0.0, 1.0) : 1.0;
    final sc = 0.6 + 0.4 * s;
    // Shadow.
    c.drawEllipse(
        Rect.fromCenter(
            center: o + Offset(2, cell * 0.28),
            width: cell * 0.6 * sc,
            height: cell * 0.18 * sc),
        Paint()..color = Colors.black26);
    // Base platform.
    c.drawRRect(
        RRect.fromLTRBR(
            o.dx - cell * 0.36 * sc,
            o.dy - cell * 0.1 * sc,
            o.dx + cell * 0.36 * sc,
            o.dy + cell * 0.34 * sc,
            const Radius.circular(6)),
        Paint()..color = dark);
    // Tower body.
    c.drawRRect(
        RRect.fromLTRBR(
            o.dx - cell * 0.3 * sc,
            o.dy - cell * 0.42 * sc,
            o.dx + cell * 0.3 * sc,
            o.dy + cell * 0.12 * sc,
            const Radius.circular(6)),
        Paint()..color = body);
    // Highlight for pseudo-3D.
    c.drawRRect(
        RRect.fromLTRBR(
            o.dx - cell * 0.3 * sc,
            o.dy - cell * 0.42 * sc,
            o.dx - cell * 0.12 * sc,
            o.dy + cell * 0.12 * sc,
            const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.18));
    // Crenellations.
    for (int i = -1; i <= 1; i++) {
      c.drawRect(
          Rect.fromLTWH(o.dx + i * cell * 0.2 * sc - cell * 0.07 * sc,
              o.dy - cell * 0.54 * sc, cell * 0.14 * sc, cell * 0.14 * sc),
          Paint()..color = dark);
    }
    // Weapon barrel aimed at target.
    final dir = Offset(cos(tw.angle), sin(tw.angle));
    final start = o + Offset(0, -cell * 0.3 * sc);
    c.drawLine(
        start,
        start + dir * cell * 0.42 * sc,
        Paint()
          ..color = dark
          ..strokeWidth = cell * 0.14 * sc
          ..strokeCap = StrokeCap.round);
    // Level pips.
    for (int i = 0; i < tw.level; i++) {
      c.drawCircle(
          Offset(o.dx - cell * 0.18 * sc + i * cell * 0.18 * sc,
              o.dy + cell * 0.24 * sc),
          cell * 0.06,
          Paint()..color = theme.accent);
    }
    // Upgrade sparkle.
    if (tw.upgradeFlash > 0) {
      c.drawCircle(
          o,
          cell * (0.5 + (0.8 - tw.upgradeFlash) * 0.6),
          Paint()
            ..color = theme.accent
                .withValues(alpha: tw.upgradeFlash.clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
  }

  void _drawCreep(Canvas c, Creep cr, double cell) {
    final p = engine.posAt(cr.dist);
    final o = Offset(p.dx * cell, p.dy * cell);
    final paint = _enemyPaints[enemyStyle.clamp(0, 7)];
    final base = Color(paint[0]);
    final dark = Color(paint[1]);
    // Death poof: shrink + fade.
    double alpha = 1.0;
    double sc = 1.0;
    if (cr.deathT >= 0) {
      final k = (cr.deathT / 0.35).clamp(0.0, 1.0);
      alpha = k;
      sc = 0.5 + 0.5 * k;
    }
    final boss = cr.kind == 'boss';
    final r = cell * (boss ? 0.4 : cr.kind == 'swarm' ? 0.2 : 0.28) * sc;
    // Shadow.
    c.drawEllipse(
        Rect.fromCenter(
            center: o + const Offset(1, 4), width: r * 1.6, height: r * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.25 * alpha));
    // Wobble hop.
    final hop = sin(cr.wobble) * cell * 0.04;
    final body = o + Offset(0, hop - r * 0.2);
    // Body.
    c.drawCircle(body, r, Paint()..color = base.withValues(alpha: alpha));
    c.drawCircle(
        body + Offset(-r * 0.25, -r * 0.25),
        r * 0.55,
        Paint()..color = Colors.white.withValues(alpha: 0.25 * alpha));
    // Kind-specific bits.
    switch (cr.kind) {
      case 'brute' || 'boss':
        // Horns.
        for (final s in [-1, 1]) {
          c.drawLine(
              body + Offset(s * r * 0.5, -r * 0.6),
              body + Offset(s * r * 0.85, -r * 1.15),
              Paint()
                ..color = dark.withValues(alpha: alpha)
                ..strokeWidth = r * 0.28
                ..strokeCap = StrokeCap.round);
        }
      case 'shield':
        // Armor plate.
        c.drawArc(
            Rect.fromCircle(center: body, radius: r * 0.95),
            pi * 1.15,
            pi * 0.7,
            false,
            Paint()
              ..color = dark.withValues(alpha: alpha)
              ..strokeWidth = r * 0.4
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round);
      case 'runner':
        // Speed stripes.
        for (int i = 0; i < 2; i++) {
          c.drawLine(
              body + Offset(-r * 1.6 - i * r * 0.5, -r * 0.3 + i * r * 0.5),
              body + Offset(-r * 0.9 - i * r * 0.5, -r * 0.3 + i * r * 0.5),
              Paint()
                ..color = Colors.white.withValues(alpha: 0.5 * alpha)
                ..strokeWidth = r * 0.22
                ..strokeCap = StrokeCap.round);
        }
      case 'swarm':
        // Antennae.
        for (final s in [-1, 1]) {
          c.drawLine(
              body + Offset(s * r * 0.3, -r * 0.7),
              body + Offset(s * r * 0.6, -r * 1.2),
              Paint()
                ..color = dark.withValues(alpha: alpha)
                ..strokeWidth = r * 0.2
                ..strokeCap = StrokeCap.round);
        }
    }
    // Eyes.
    for (final s in [-1, 1]) {
      c.drawCircle(
          body + Offset(s * r * 0.32, -r * 0.1),
          r * 0.22,
          Paint()..color = Colors.white.withValues(alpha: alpha));
      c.drawCircle(
          body + Offset(s * r * 0.32, -r * 0.06),
          r * 0.11,
          Paint()..color = Colors.black.withValues(alpha: alpha));
    }
    // Frost tint.
    if (cr.slowT > 0) {
      c.drawCircle(
          body,
          r * 1.15,
          Paint()
            ..color = const Color(0xFF7EC8E3)
                .withValues(alpha: 0.35 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    // Poison tint.
    if (cr.poisonT > 0) {
      c.drawCircle(
          body,
          r * 1.3,
          Paint()
            ..color = const Color(0xFF7AC83E)
                .withValues(alpha: 0.35 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    // HP bar.
    if (cr.deathT < 0) {
      final f = (cr.hp / cr.maxHp).clamp(0.0, 1.0);
      final bw = cell * (boss ? 0.9 : 0.6);
      final by = o.dy - r - cell * 0.16;
      c.drawRRect(
          RRect.fromLTRBR(o.dx - bw / 2, by, o.dx + bw / 2, by + 5,
              const Radius.circular(2.5)),
          Paint()..color = Colors.black45);
      c.drawRRect(
          RRect.fromLTRBR(o.dx - bw / 2, by,
              o.dx - bw / 2 + bw * f, by + 5, const Radius.circular(2.5)),
          Paint()
            ..color = f > 0.5
                ? const Color(0xFF5EB85E)
                : const Color(0xFFE08A3E));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
