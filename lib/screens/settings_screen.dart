import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/td_themes.dart';

/// Settings: renameable commander profile, audio toggles + volume,
/// share, rate, credits.
class SettingsScreen extends StatelessWidget {
  final TDAudio audio;
  final TDSettings settings;
  final StoreService store;
  const SettingsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.gameswajiha.towerdefense';

  TDThemeDef get _t => TDThemes.byId(settings.themeId,
      custom: settings.customTheme);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.card,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.text),
          onPressed: () {
            audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Settings', style: TDStyle.display(22, t)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (_, _) => ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            children: [
              _section(t, 'COMMANDER', [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Name',
                      style: TDStyle.label(14, t)),
                  subtitle: Text(settings.playerName,
                      style: TDStyle.body(16, t)),
                  trailing:
                      Icon(Icons.edit, color: t.accentDark),
                  onTap: () => _rename(context, t),
                ),
              ]),
              _section(t, 'AUDIO', [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Music',
                      style: TDStyle.label(14, t)),
                  value: settings.musicOn,
                  activeThumbColor: t.accent,
                  onChanged: (v) {
                    settings.setMusic(v);
                    audio.configure(
                        musicOn: v,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) {
                      audio.startMenuMusic();
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Sound effects',
                      style: TDStyle.label(14, t)),
                  value: settings.sfxOn,
                  activeThumbColor: t.accent,
                  onChanged: (v) {
                    settings.setSfx(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: v,
                        volume: settings.volume);
                    if (v) audio.click();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Volume',
                      style: TDStyle.label(14, t)),
                  subtitle: Slider(
                    value: settings.volume,
                    activeColor: t.accent,
                    onChanged: (v) {
                      settings.setVolume(v);
                      audio.configure(
                          musicOn: settings.musicOn,
                          sfxOn: settings.sfxOn,
                          volume: v);
                    },
                  ),
                ),
              ]),
              _section(t, 'SHARE & RATE', [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text('📤',
                      style: TDStyle.body(22, t)),
                  title: Text('Tell a friend',
                      style: TDStyle.label(14, t)),
                  onTap: () {
                    audio.click();
                    SharePlus.instance.share(ShareParams(
                        text:
                            'I\'m holding the castle in Tower Defense — '
                            'can you survive all 30 waves? $_storeUrl'));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text('⭐',
                      style: TDStyle.body(22, t)),
                  title: Text('Rate Tower Defense',
                      style: TDStyle.label(14, t)),
                  onTap: () async {
                    audio.click();
                    try {
                      if (await InAppReview.instance
                          .isAvailable()) {
                        await InAppReview.instance
                            .requestReview();
                      } else {
                        await InAppReview.instance
                            .openStoreListing(
                                appStoreId:
                                    'com.gameswajiha.towerdefense');
                      }
                    } catch (_) {}
                  },
                ),
              ]),
              _section(t, 'RECORDS', [
                _record(t, '🏆', 'Best campaign wave',
                    '${settings.bestWave}/30'),
                _record(t, '♾️', 'Best endless wave',
                    '${settings.bestEndless}'),
                _record(t, '⚔️', 'Campaigns won',
                    '${settings.campaignWins}'),
                _record(t, '👹', 'Creeps defeated',
                    '${settings.totalKills}'),
                _record(t, '🎮', 'Games played',
                    '${settings.gamesPlayed}'),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/wajiha_logo.png',
                      width: 26, height: 26, fit: BoxFit.contain),
                  const SizedBox(width: 8),
                  Text('Credits: WAJIHA',
                      style: TDStyle.label(13, t)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Tower Defense v2.0 • Made with 💛',
                  style: TDStyle.body(12, t, color: t.muted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(TDThemeDef t, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.cardDeep.withValues(alpha: 0.5),
        border: Border.all(color: t.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(title, style: TDStyle.label(11, t)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _record(TDThemeDef t, String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: TDStyle.body(16, t)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TDStyle.body(14, t))),
          Text(value, style: TDStyle.label(14, t)),
        ],
      ),
    );
  }

  void _rename(BuildContext context, TDThemeDef t) {
    final ctrl = TextEditingController(text: settings.playerName);
    // Save on EVERY keystroke (single order-safe JSON string — never
    // setStringList); the Save button commits on focus loss / tap.
    ctrl.addListener(() => settings.setPlayerName(ctrl.text));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.card,
        title:
            Text('Commander name', style: TDStyle.display(20, t)),
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
