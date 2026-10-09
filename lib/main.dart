import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/settings_service.dart';
import 'theme/td_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = TDSettings();
  await settings.load();
  final audio = TDAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  final store = StoreService();
  // Store init runs in the background; the Pro screen copes with
  // not-yet-ready state.
  unawaited(store.init());
  runApp(TowerDefenseApp(settings: settings, audio: audio, store: store));
}

class TowerDefenseApp extends StatefulWidget {
  final TDSettings settings;
  final TDAudio audio;
  final StoreService store;
  const TowerDefenseApp(
      {super.key,
      required this.settings,
      required this.audio,
      required this.store});

  @override
  State<TowerDefenseApp> createState() => _TowerDefenseAppState();
}

class _TowerDefenseAppState extends State<TowerDefenseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    widget.store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = TDThemes.byId(widget.settings.themeId,
            custom: widget.settings.customTheme);
        return MaterialApp(
          title: 'Tower Defense',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.card,
            colorScheme: ColorScheme.light(
              primary: theme.accent,
              secondary: theme.accentDark,
              surface: theme.card,
              onSurface: theme.text,
            ),
            textTheme: TextTheme(
              bodyMedium: TDStyle.body(15, theme),
              titleLarge: TDStyle.display(20, theme),
            ),
          ),
          home: SplashScreen(
            audio: widget.audio,
            settings: widget.settings,
            store: widget.store,
          ),
        );
      },
    );
  }
}
