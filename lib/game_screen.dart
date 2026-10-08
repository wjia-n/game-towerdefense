import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class TowerDefenseScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const TowerDefenseScreen({super.key, required this.players, required this.callbacks});
  @override
  State<TowerDefenseScreen> createState() => _TowerDefenseScreenState();
}

class _Creep {
  double dist; double hp; double maxHp; double speed; int reward; int dmg;
  double slowT = 0; int wave;
  _Creep(this.dist, this.hp, this.speed, this.reward, this.dmg, this.wave) : maxHp = hp;
}

class _Tower {
  int col, row; String kind; int level = 1; int invested;
  double cooldown = 0; double angle = 0;
  _Tower(this.col, this.row, this.kind, this.invested);
}

class _Bolt { double x, y; _Creep target; double dmg; double splash; double slow; _Bolt(this.x,this.y,this.target,this.dmg,this.splash,this.slow); }

class _TowerDefenseScreenState extends State<TowerDefenseScreen> {
  static const cols = 9, rows = 9;
  static const path = [[0,1],[7,1],[7,4],[2,4],[2,7],[8,7]];
  static const specs = {
    'arrow':  {'cost': 50,  'range': 2.3, 'dmg': 8.0,  'rate': 2.0, 'splash': 0.0, 'slow': 0.0,  'emoji': '🏹'},
    'cannon': {'cost': 120, 'range': 2.7, 'dmg': 32.0, 'rate': 0.65,'splash': 1.3, 'slow': 0.0,  'emoji': '💣'},
    'frost':  {'cost': 90,  'range': 2.1, 'dmg': 3.0,  'rate': 1.2, 'splash': 0.0, 'slow': 0.45, 'emoji': '❄️'},
  };

  final rnd = Random();
  final List<_Creep> creeps = [];
  final List<_Tower> towers = [];
  final List<_Bolt> bolts = [];
  int gold = 220, lives = 20, wave = 0, best = 0;
  bool waveRunning = false, over = false;
  double spawnT = 0; int toSpawn = 0; double spawnGap = 0.8;
  int selC = -1, selR = -1;
  late List<double> segLens; late double pathLen;

  @override
  void initState() {
    super.initState();
    segLens = [];
    for (int i = 0; i < path.length - 1; i++) {
      segLens.add(((path[i+1][0]-path[i][0]).abs() + (path[i+1][1]-path[i][1]).abs()).toDouble());
    }
    pathLen = segLens.fold(0.0, (a,b) => a+b);
    _loadBest();
    Timer.periodic(const Duration(milliseconds: 50), _tick);
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => best = p.getInt('td_best') ?? 0);
  }

  Offset _posAt(double d) {
    double r = d;
    for (int i = 0; i < segLens.length; i++) {
      if (r <= segLens[i]) {
        final t = r / segLens[i];
        return Offset(path[i][0] + (path[i+1][0]-path[i][0])*t + 0.5,
                      path[i][1] + (path[i+1][1]-path[i][1])*t + 0.5);
      }
      r -= segLens[i];
    }
    return Offset(path.last[0] + 0.5, path.last[1] + 0.5);
  }

  bool _onPath(int c, int r) {
    final cells = <String>{};
    for (int i = 0; i < path.length - 1; i++) {
      int c0 = path[i][0], r0 = path[i][1], c1 = path[i+1][0], r1 = path[i+1][1];
      for (int c = min(c0,c1); c <= max(c0,c1); c++) {
        for (int r = min(r0,r1); r <= max(r0,r1); r++) { cells.add('$c,$r'); }
      }
    }
    return cells.contains('$c,$r');
  }

  void _startWave() {
    if (waveRunning || over || wave >= 20) return;
    wave++;
    waveRunning = true;
    final boss = wave % 5 == 0;
    toSpawn = boss ? 3 : 6 + wave;
    spawnGap = max(0.25, 0.9 - wave * 0.03);
    spawnT = 0;
    Sfx.click();
    setState(() {});
  }

  void _spawn() {
    final boss = wave % 5 == 0;
    final hp = (boss ? 20 * pow(1.18, wave) * 10 : 20 * pow(1.18, wave)).toDouble();
    creeps.add(_Creep(-0.5 - toSpawn * 0.4, hp, (0.85 + wave * 0.035) * (boss ? 0.7 : 1),
        boss ? 60 + wave * 4 : 6 + wave, boss ? 3 : 1, wave));
    toSpawn--;
  }

  void _tick(Timer t) {
    if (!mounted || over) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    const dt = 0.05;
    setState(() {
      if (waveRunning && toSpawn > 0) {
        spawnT -= dt;
        if (spawnT <= 0) { _spawn(); spawnT = spawnGap; }
      }
      for (final c in creeps) {
        if (c.slowT > 0) c.slowT -= dt;
        c.dist += c.speed * (c.slowT > 0 ? 0.55 : 1) * dt;
        if (c.dist >= pathLen) {
          lives -= c.dmg; c.hp = -1;
          Sfx.lose();
          if (lives <= 0) { lives = 0; _end(false); return; }
        }
      }
      creeps.removeWhere((c) => c.hp <= 0 && c.dist >= pathLen);
      // towers fire
      for (final tw in towers) {
        tw.cooldown -= dt;
        final s = specs[tw.kind]!;
        final range = (s['range'] as double) + (tw.level - 1) * 0.35;
        _Creep? bestT; double bestD = -1;
        final tp = Offset(tw.col + 0.5, tw.row + 0.5);
        for (final c in creeps) {
          if (c.hp <= 0) continue;
          final p = _posAt(c.dist);
          if ((p - tp).distance <= range && c.dist > bestD) { bestD = c.dist; bestT = c; }
        }
        if (bestT != null) {
          final p = _posAt(bestT.dist);
          tw.angle = atan2(p.dy - tp.dy, p.dx - tp.dx);
          if (tw.cooldown <= 0) {
            tw.cooldown = 1 / (s['rate'] as double);
            final dmg = (s['dmg'] as double) * (tw.level == 1 ? 1 : 1.9);
            bolts.add(_Bolt(tp.dx, tp.dy, bestT, dmg, s['splash'] as double, s['slow'] as double));
          }
        }
      }
      // bolts
      final dead = <_Bolt>[];
      for (final b in bolts) {
        if (b.target.hp <= 0) { dead.add(b); continue; }
        final p = _posAt(b.target.dist);
        final d = (p - Offset(b.x, b.y)).distance;
        if (d < 0.25) {
          if (b.splash > 0) {
            for (final c in creeps) {
              if (c.hp > 0 && (_posAt(c.dist) - p).distance <= b.splash) c.hp -= b.dmg;
            }
          } else {
            b.target.hp -= b.dmg;
            if (b.slow > 0) b.target.slowT = 2.0;
          }
          dead.add(b);
        } else {
          final step = 14 * dt;
          b.x += (p.dx - b.x) / d * step; b.y += (p.dy - b.y) / d * step;
        }
      }
      bolts.removeWhere((b) => dead.contains(b));
      // deaths
      for (final c in creeps.where((c) => c.hp <= 0 && c.dist < pathLen).toList()) {
        gold += c.reward; widget.players.first.score += c.reward;
      }
      creeps.removeWhere((c) => c.hp <= 0 && c.dist < pathLen);
      if (waveRunning && toSpawn == 0 && creeps.isEmpty) {
        waveRunning = false;
        Sfx.win();
        if (wave >= 20) _end(true);
      }
    });
  }

  Future<void> _end(bool won) async {
    if (over) return; over = true;
    if (wave > best) {
      best = wave;
      final p = await SharedPreferences.getInstance();
      await p.setInt('td_best', best);
    }
    widget.callbacks.finish(
      headline: won ? '🏰 The castle stands! All 20 waves repelled!' : '💥 The castle fell on wave $wave',
      subline: won ? 'Gold earned: ${widget.players.first.score}' : 'Best: wave $best',
    );
  }

  void _onTapCell(int c, int r) {
    if (over) return;
    final ti = towers.indexWhere((t) => t.col == c && t.row == r);
    setState(() { selC = c; selR = r; });
    if (ti >= 0 || _onPath(c, r)) { Sfx.tap(); return; }
    Sfx.tap();
  }

  void _place(String kind) {
    final cost = (specs[kind]!['cost'] as int);
    if (gold < cost || selC < 0) return;
    gold -= cost;
    towers.add(_Tower(selC, selR, kind, cost));
    Sfx.move();
    setState(() { selC = -1; selR = -1; });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final ti = towers.indexWhere((x) => x.col == selC && x.row == selR);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _hud(t, '💰', '$gold'), _hud(t, '❤️', '$lives'),
          _hud(t, '🌊', '$wave/20'), _hud(t, '🏆', 'best $best'),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(builder: (ctx, box) {
            final cell = min(box.maxWidth / cols, box.maxHeight / rows);
            return GestureDetector(
              onTapDown: (d) => _onTapCell(
                (d.localPosition.dx / cell).floor().clamp(0, cols - 1),
                (d.localPosition.dy / cell).floor().clamp(0, rows - 1)),
              child: CustomPaint(
                size: Size(cell * cols, cell * rows),
                painter: _BoardPainter(t, creeps, towers, bolts, selC, selR, path, _posAt),
              ),
            );
          }),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
        margin: const EdgeInsets.all(8),
        child: ti >= 0
            ? _towerPanel(t, towers[ti])
            : (selC >= 0 && !_onPath(selC, selR))
                ? _buildPanel(t)
                : (waveRunning
                    ? Text('🌊 Wave $wave incoming… hold the line!', style: TextStyle(color: t.muted))
                    : WajihaButton(label: wave >= 20 ? 'Done' : 'Start wave ${wave + 1}', emoji: '⚔️', onTap: _startWave, primary: true)),
      ),
    ]);
  }

  Widget _hud(GameTheme t, String e, String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
    child: Text('$e $v', style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
  );

  Widget _buildPanel(GameTheme t) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: specs.entries.map((e) {
      final cost = e.value['cost'] as int;
      final afford = gold >= cost;
      return GestureDetector(
        onTap: afford ? () => _place(e.key) : null,
        child: Opacity(
          opacity: afford ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: t.background, borderRadius: t.radius),
            child: Text('${e.value['emoji']}\n💰$cost', textAlign: TextAlign.center,
                style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }).toList(),
  );

  Widget _towerPanel(GameTheme t, _Tower tw) {
    final upCost = (tw.invested * 0.8).round();
    final sellV = (tw.invested * 0.7).round();
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Text('${specs[tw.kind]!['emoji']} Lv${tw.level}', style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
      if (tw.level == 1)
        WajihaButton(label: 'Upgrade 💰$upCost', emoji: '⬆️',
            onTap: gold >= upCost ? () { gold -= upCost; tw.invested += upCost; tw.level = 2; Sfx.click(); setState(() {}); } : () {}),
      WajihaButton(label: 'Sell 💰$sellV', emoji: '💸', onTap: () {
        gold += sellV; towers.remove(tw); Sfx.click();
        setState(() { selC = -1; selR = -1; });
      }),
      WajihaButton(label: 'Close', emoji: '✖️', onTap: () => setState(() { selC = -1; selR = -1; })),
    ]);
  }
}

class _BoardPainter extends CustomPainter {
  final GameTheme t; final List<_Creep> creeps; final List<_Tower> towers;
  final List<_Bolt> bolts; final int selC, selR;
  final List<List<int>> path;
  final Offset Function(double) posAt;
  _BoardPainter(this.t, this.creeps, this.towers, this.bolts, this.selC, this.selR, this.path, this.posAt);

  @override
  void paint(Canvas c, Size size) {
    final cell = size.width / 9;
    final grass = Paint()..color = t.surface;
    c.drawRRect(RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(12)), grass);
    // path
    final road = Paint()..color = t.muted.withValues(alpha: 0.45);
    for (int i = 0; i < path.length - 1; i++) {
      c.drawLine(Offset((path[i][0]+0.5)*cell, (path[i][1]+0.5)*cell),
                 Offset((path[i+1][0]+0.5)*cell, (path[i+1][1]+0.5)*cell), road..strokeWidth = cell*0.7..style=PaintingStyle.stroke);
    }
    road.style = PaintingStyle.fill;
    // selection
    if (selC >= 0) {
      c.drawRRect(RRect.fromLTRBR(selC*cell, selR*cell, (selC+1)*cell, (selR+1)*cell, const Radius.circular(6)),
          Paint()..color = t.accent.withValues(alpha: 0.3));
    }
    // towers
    for (final tw in towers) {
      final o = Offset((tw.col+0.5)*cell, (tw.row+0.5)*cell);
      c.drawCircle(o, cell*0.34, Paint()..color = t.primary);
      c.drawCircle(o, cell*0.34, Paint()..color = t.text.withValues(alpha: 0.15)..style=PaintingStyle.stroke..strokeWidth=2);
      final e = _TowerDefenseScreenState.specs[tw.kind]!['emoji'] as String;
      final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: cell*0.4)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, o - Offset(tp.width/2, tp.height/2));
      if (tw.level == 2) {
        c.drawCircle(o, cell*0.42, Paint()..color = t.accent..style=PaintingStyle.stroke..strokeWidth=3);
      }
      // barrel
      c.drawLine(o, o + Offset(cos(tw.angle), sin(tw.angle))*cell*0.5,
          Paint()..color = t.text..strokeWidth=4..strokeCap=StrokeCap.round);
    }
    // creeps
    for (final cr in creeps) {
      if (cr.hp <= 0) continue;
      final p = posAt(cr.dist);
      final o = Offset(p.dx*cell, p.dy*cell);
      final boss = cr.wave % 5 == 0;
      c.drawCircle(o, cell*(boss?0.42:0.3), Paint()..color = cr.slowT > 0 ? Colors.lightBlue : Colors.redAccent);
      final f = (cr.hp / cr.maxHp).clamp(0.0, 1.0);
      c.drawRRect(RRect.fromLTRBR(o.dx-cell*0.35, o.dy-cell*0.5, o.dx+cell*0.35, o.dy-cell*0.4, const Radius.circular(3)),
          Paint()..color = Colors.black45);
      c.drawRRect(RRect.fromLTRBR(o.dx-cell*0.35, o.dy-cell*0.5, o.dx-cell*0.35+cell*0.7*f, o.dy-cell*0.4, const Radius.circular(3)),
          Paint()..color = f > 0.5 ? Colors.green : Colors.orange);
    }
    // bolts
    for (final b in bolts) {
      c.drawCircle(Offset(b.x*cell, b.y*cell), 4, Paint()..color = t.accent);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
