import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/td_themes.dart';
import 'pro_screen.dart';

/// Theme picker: 12 meadow themes + custom creator, tower styles, enemy styles.
class ThemesScreen extends StatefulWidget {
  final TDAudio audio;
  final TDSettings settings;
  final StoreService store;
  final int initialTab; // 0 themes, 1 towers & foes
  const ThemesScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store,
      this.initialTab = 0});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  TDThemeDef get _t => TDThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  void _goPro() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProScreen(
            audio: widget.audio,
            settings: widget.settings,
            store: widget.store)));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return Scaffold(
      backgroundColor: t.card,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.text),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Looks', style: TDStyle.display(22, t)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    for (int i = 0; i < 2; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              widget.audio.click();
                              setState(() => _tab = i);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _tab == i ? t.accent : t.cardDeep,
                                border: Border.all(color: t.accent),
                              ),
                              child: Text(
                                i == 0 ? '🎨 Themes' : '🗼 Towers & Foes',
                                textAlign: TextAlign.center,
                                style: TDStyle.label(13, t,
                                    color: _tab == i
                                        ? Colors.white
                                        : t.text),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _tab == 0
                    ? _themeList(t, s)
                    : _stylesList(t, s),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeList(TDThemeDef t, TDSettings s) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      children: [
        for (final th in TDThemes.all)
          _themeTile(t, s, th.id, th.name, th),
        _themeTile(t, s, 'custom', 'My Creation (PRO)', s.customTheme,
            isCustom: true),
      ],
    );
  }

  Widget _themeTile(
      TDThemeDef t, TDSettings s, String id, String name, TDThemeDef preview,
      {bool isCustom = false}) {
    final locked = !s.isPro &&
        (id == 'custom' || TDThemes.isProTheme(id));
    final selected = s.themeId == id;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
        } else {
          s.setTheme(id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? t.accent.withValues(alpha: 0.25)
              : t.cardDeep.withValues(alpha: 0.5),
          border: Border.all(
              color: selected ? t.accent : t.muted.withValues(alpha: 0.4),
              width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            // Mini preview swatches.
            SizedBox(
              width: 84,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(child: Container(color: preview.grassLight)),
                    Expanded(child: Container(color: preview.roadLight)),
                    Expanded(child: Container(color: preview.wood)),
                    Expanded(child: Container(color: preview.accent)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: TDStyle.label(14, t)),
            ),
            if (locked)
              Text('🔒', style: TDStyle.body(16, t))
            else if (selected)
              Text('✓', style: TDStyle.body(16, t, color: t.accentDark)),
            if (isCustom && !locked)
              IconButton(
                icon: Icon(Icons.edit, color: t.accentDark),
                onPressed: () {
                  widget.audio.click();
                  _customCreator(t, s);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _stylesList(TDThemeDef t, TDSettings s) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      children: [
        Text('TOWER FINISH', style: TDStyle.label(12, t)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < TowerStyles.names.length; i++)
              _styleChip(
                t,
                TowerStyles.names[i],
                locked: !s.isPro && TowerStyles.isPro(i),
                selected: s.towerStyle == i,
                onTap: () {
                  widget.audio.click();
                  if (!s.isPro && TowerStyles.isPro(i)) {
                    _goPro();
                  } else {
                    s.setTowerStyle(i);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('ENEMY PAINT', style: TDStyle.label(12, t)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < EnemyStyles.names.length; i++)
              _styleChip(
                t,
                EnemyStyles.names[i],
                locked: !s.isPro && EnemyStyles.isPro(i),
                selected: s.enemyStyle == i,
                onTap: () {
                  widget.audio.click();
                  if (!s.isPro && EnemyStyles.isPro(i)) {
                    _goPro();
                  } else {
                    s.setEnemyStyle(i);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('MAP STYLE', style: TDStyle.label(12, t)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < MapStyles.names.length; i++)
              _styleChip(
                t,
                MapStyles.names[i],
                locked: !s.isPro && MapStyles.isPro(i),
                selected: s.mapStyle == i,
                onTap: () {
                  widget.audio.click();
                  if (!s.isPro && MapStyles.isPro(i)) {
                    _goPro();
                  } else {
                    s.setMapStyle(i);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'PRO unlocks 4 extra tower finishes, 4 extra enemy paints, '
          '4 extra map styles, all 12 meadow themes and the custom creator.',
          style: TDStyle.body(12, t, color: t.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _styleChip(TDThemeDef t, String name,
      {required bool locked,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? t.accent.withValues(alpha: 0.3)
              : t.cardDeep.withValues(alpha: 0.5),
          border: Border.all(
              color: selected ? t.accent : t.muted.withValues(alpha: 0.4),
              width: selected ? 2 : 1),
        ),
        child: Text(locked ? '🔒 $name' : name,
            style: TDStyle.label(12, t)),
      ),
    );
  }

  /// Custom theme creator (PRO): pick colors for the battlefield.
  void _customCreator(TDThemeDef t, TDSettings s) {
    const keys = [
      ('grassLight', 'Grass'),
      ('grassDark', 'Grass shade'),
      ('roadLight', 'Road'),
      ('roadDark', 'Road shade'),
      ('wood', 'Tower wood'),
      ('stone', 'Stone'),
      ('accent', 'Accent'),
      ('card', 'Panels'),
      ('creepBase', 'Creep paint'),
    ];
    const palette = [
      0xFF9CCB6B,
      0xFF7BAF4E,
      0xFFE3C98F,
      0xFFC9A86B,
      0xFF9C6B3F,
      0xFFB8B0A0,
      0xFFD97B2B,
      0xFFF3E9D2,
      0xFFB8452E,
      0xFF2B7FA8,
      0xFF8A4E9E,
      0xFF4E8A2E,
      0xFFD9A42B,
      0xFF6E6E7A,
      0xFFDDEAF2,
      0xFF4E3428,
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('My Creation', style: TDStyle.display(20, t)),
                const SizedBox(height: 4),
                Text('Pick a part, then a color.',
                    style: TDStyle.body(13, t, color: t.muted)),
                const SizedBox(height: 12),
                for (final k in keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 100,
                            child: Text(k.$2,
                                style: TDStyle.label(12, t))),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final c in palette)
                                GestureDetector(
                                  onTap: () {
                                    s.setCustomColor(k.$1, c);
                                    setSheet(() {});
                                  },
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Color(c),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: s.customColors[k.$1] == c
                                            ? t.accentDark
                                            : Colors.black26,
                                        width: s.customColors[k.$1] == c
                                            ? 3
                                            : 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        s.resetCustomColors();
                        setSheet(() {});
                      },
                      child: Text('Reset',
                          style: TDStyle.label(13, t)),
                    ),
                    ElevatedButton(
                      style: TDStyle.primary(t),
                      onPressed: () {
                        widget.audio.click();
                        s.setTheme('custom');
                        Navigator.of(context).pop();
                      },
                      child: const Text('Use this theme'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
