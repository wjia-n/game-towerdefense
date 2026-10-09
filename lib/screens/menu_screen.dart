import 'package:flutter/material.dart';
import '../engine/td_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/td_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

/// Main menu: mode + difficulty select, profile, stats, navigation.
class MenuScreen extends StatelessWidget {
  final TDAudio audio;
  final TDSettings settings;
  final StoreService store;
  const MenuScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  static const difficultyNames = ['Recruit', 'Defender', 'Legend'];
  static const difficultyBlurb = [
    'Gentle waves, 20 lives, 300 gold. Learn the ropes.',
    'The real battle: 15 lives, 250 gold, full creep roster.',
    'PRO: tougher, faster creeps. Only for legends.',
  ];

  void _play(BuildContext context, {required bool endless}) {
    audio.gameStart();
    audio.startGameMusic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: audio,
          settings: settings,
          store: store,
          config: TDGameConfig(
            difficulty: settings.difficulty,
            endless: endless,
            seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
          ),
        ),
      ),
    ).then((_) => audio.startMenuMusic());
  }

  @override
  Widget build(BuildContext context) {
    final t = TDThemes.byId(settings.themeId, custom: settings.customTheme);
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) => Scaffold(
        backgroundColor: t.card,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              children: [
                // Logo + title.
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: t.accent, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/towerdefense_logo.png',
                      fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
                Text('Tower Defense', style: TDStyle.display(38, t)),
                Text('HOLD THE CASTLE',
                    style: TDStyle.label(12, t)),
                const SizedBox(height: 8),
                _ProfileChip(t: t, settings: settings, audio: audio),
                const SizedBox(height: 16),
                // Play buttons.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: TDStyle.primary(t),
                    onPressed: () {
                      audio.click();
                      _play(context, endless: false);
                    },
                    child: const Text('⚔️  Campaign — 30 Waves'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: TDStyle.soft(t),
                    onPressed: () {
                      audio.click();
                      _play(context, endless: true);
                    },
                    child: const Text('♾️  Endless Siege'),
                  ),
                ),
                const SizedBox(height: 16),
                // Difficulty selector.
                _Card(
                  t: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DIFFICULTY', style: TDStyle.label(12, t)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (int i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _DiffChip(
                                  t: t,
                                  label: difficultyNames[i],
                                  locked: i == 2 && !settings.isPro,
                                  selected: settings.difficulty == i,
                                  onTap: () {
                                    audio.click();
                                    if (i == 2 && !settings.isPro) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProScreen(
                                            audio: audio,
                                            settings: settings,
                                            store: store,
                                          ),
                                        ),
                                      );
                                    } else {
                                      settings.setDifficulty(i);
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(difficultyBlurb[settings.difficulty],
                          style: TDStyle.body(13, t, color: t.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Stats.
                _Card(
                  t: t,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(t, '🏆', 'Best wave', '${settings.bestWave}/30'),
                      _Stat(t, '♾️', 'Best endless', '${settings.bestEndless}'),
                      _Stat(t, '👹', 'Creeps down', '${settings.totalKills}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Nav grid.
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: [
                    _NavTile(
                        t: t,
                        emoji: '🎨',
                        label: 'Themes',
                        onTap: () {
                          audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ThemesScreen(
                                  audio: audio,
                                  settings: settings,
                                  store: store)));
                        }),
                    _NavTile(
                        t: t,
                        emoji: '🗼',
                        label: 'Towers & Foes',
                        onTap: () {
                          audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ThemesScreen(
                                  audio: audio,
                                  settings: settings,
                                  store: store,
                                  initialTab: 1)));
                        }),
                    _NavTile(
                        t: t,
                        emoji: '⚙️',
                        label: 'Settings',
                        onTap: () {
                          audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                  audio: audio,
                                  settings: settings,
                                  store: store)));
                        }),
                    _NavTile(
                        t: t,
                        emoji: '⭐',
                        label: settings.isPro ? 'PRO ✓' : 'Go PRO',
                        onTap: () {
                          audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProScreen(
                                  audio: audio,
                                  settings: settings,
                                  store: store)));
                        }),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    audio.click();
                    _howToPlay(context, t);
                  },
                  child: Text('How to play',
                      style: TDStyle.label(13, t)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _howToPlay(BuildContext context, TDThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.card,
        title: Text('How to play', style: TDStyle.display(22, t)),
        content: Text(
          '• Tap an empty grass tile, pick a tower, and place it.\n'
          '• Towers attack creeps marching along the dirt road.\n'
          '• Tap a tower to upgrade (up to Lv${settings.isPro ? 3 : 2}) or sell it.\n'
          '• Each kill earns gold. Finish a wave for a bonus.\n'
          '• Boss creeps arrive every 5 waves — save up!\n'
          '• If creeps breach the castle gate, you lose lives.\n'
          '• Campaign: survive all 30 waves. Endless: how long can you hold?',
          style: TDStyle.body(14, t),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it!', style: TDStyle.label(14, t)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final TDThemeDef t;
  final Widget child;
  const _Card({required this.t, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final TDThemeDef t;
  final TDSettings settings;
  final TDAudio audio;
  const _ProfileChip(
      {required this.t, required this.settings, required this.audio});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        audio.click();
        _rename(context);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.accent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛡️ ${settings.playerName}',
                style: TDStyle.label(15, t)),
            const SizedBox(width: 6),
            Icon(Icons.edit, size: 14, color: t.muted),
          ],
        ),
      ),
    );
  }

  void _rename(BuildContext context) {
    final ctrl = TextEditingController(text: settings.playerName);
    // Save on EVERY keystroke (single order-safe JSON string — never
    // setStringList); the Save button commits on focus loss / tap.
    ctrl.addListener(() => settings.setPlayerName(ctrl.text));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Commander name', style: TDStyle.display(20, t)),
        content: TextField(
          controller: ctrl,
          maxLength: 16,
          style: TDStyle.body(16, t),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TDStyle.body(16, t, color: t.muted),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TDStyle.label(14, t)),
          ),
          TextButton(
            onPressed: () {
              audio.click();
              settings.setPlayerName(ctrl.text);
              Navigator.of(context).pop();
            },
            child: Text('Save', style: TDStyle.label(14, t)),
          ),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final TDThemeDef t;
  final String label;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;
  const _DiffChip(
      {required this.t,
      required this.label,
      required this.locked,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? t.accent : t.card,
          border: Border.all(
              color: selected ? t.accentDark : t.muted, width: 1.5),
        ),
        child: Text(
          locked ? '🔒 $label' : label,
          textAlign: TextAlign.center,
          style: TDStyle.label(13, t,
              color: selected ? Colors.white : t.text),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final TDThemeDef t;
  final String emoji;
  final String label;
  final String value;
  const _Stat(this.t, this.emoji, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$emoji $value', style: TDStyle.display(16, t)),
        Text(label, style: TDStyle.body(11, t, color: t.muted)),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final TDThemeDef t;
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _NavTile(
      {required this.t,
      required this.emoji,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: t.cardDeep.withValues(alpha: 0.6),
          border:
              Border.all(color: t.accent.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text('$emoji  $label',
              style: TDStyle.label(14, t)),
        ),
      ),
    );
  }
}
