import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/td_themes.dart';

/// Persisted settings + stats for Tower Defense. Survives app restarts.
///
/// The player profile (name) is stored as a SINGLE JSON string. Never use
/// setStringList for ordered data — Android stores StringLists as an
/// unordered StringSet and scrambles order.
class TDSettings extends ChangeNotifier {
  static const _kMusic = 'td_music_on';
  static const _kSfx = 'td_sfx_on';
  static const _kVolume = 'td_volume';

  /// Order-safe profile storage: ONE JSON string, e.g. {"name":"Wajiha"}.
  /// NEVER setStringList for ordered data — Android backs StringList with an
  /// unordered StringSet and scrambles order across restarts.
  /// Master-rules key: <slug>_player_names_json.
  static const _kProfileJson = 'towerdefense_player_names_json';
  // Legacy keys migrated once, then removed.
  static const _kLegacyProfileJson = 'td_profile_json';
  static const _kLegacyName = 'td_player_name';
  static const _kLegacyNames = 'td_player_names';

  static const _kTheme = 'td_theme_id';
  static const _kTowerStyle = 'td_tower_style';
  static const _kEnemyStyle = 'td_enemy_style';
  static const _kMapStyle = 'td_map_style';
  static const _kDifficulty = 'td_difficulty'; // 0 recruit, 1 defender, 2 legend
  static const _kMode = 'td_mode'; // 0 campaign, 1 endless
  static const _kBestWave = 'td_best_wave';
  static const _kBestEndless = 'td_best_endless';
  static const _kGames = 'td_games_played';
  static const _kWins = 'td_campaign_wins';
  static const _kKills = 'td_total_kills';
  static const _kIsPro = 'td_is_pro';
  static const _kCustomPrefix = 'td_custom_';

  static const defaultName = 'Defender';

  static String encodeProfile(String name) =>
      jsonEncode({'name': name.trim().isEmpty ? defaultName : name.trim()});

  static String decodeProfile(String? raw, {String? legacyName}) {
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) {
          final n = (d['name'] as Object?).toString().trim();
          if (n.isNotEmpty && n != 'null') return n;
        }
      } catch (_) {}
    }
    final ln = (legacyName ?? '').trim();
    return ln.isEmpty ? defaultName : ln;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = defaultName;
  String themeId = 'meadow';
  int towerStyle = 0;
  int enemyStyle = 0;
  int mapStyle = 0;
  int difficulty = 0;
  int mode = 0; // 0 campaign (30 waves), 1 endless
  int bestWave = 0;
  int bestEndless = 0;
  int gamesPlayed = 0;
  int campaignWins = 0;
  int totalKills = 0;
  bool isPro = true; // everything unlocked — no Pro version

  /// Custom theme colors (ARGB ints). Defaults mirror the Green Meadow.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'grassLight': 0xFF9CCB6B,
    'grassDark': 0xFF7BAF4E,
    'roadLight': 0xFFE3C98F,
    'roadDark': 0xFFC9A86B,
    'wood': 0xFF9C6B3F,
    'stone': 0xFFB8B0A0,
    'accent': 0xFFD97B2B,
    'card': 0xFFF3E9D2,
    'creepBase': 0xFFB8452E,
  };

  /// Builds the user-designed custom theme from stored colors.
  TDThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    Color shade(Color base, double f) => Color.fromARGB(
          0xFF,
          (base.r * 255 * f).round().clamp(0, 255).toInt(),
          (base.g * 255 * f).round().clamp(0, 255).toInt(),
          (base.b * 255 * f).round().clamp(0, 255).toInt(),
        );
    final wood = c('wood');
    final stone = c('stone');
    final accent = c('accent');
    final grass = c('grassLight');
    final road = c('roadLight');
    final creep = c('creepBase');
    return TDThemeDef(
      id: 'custom',
      name: 'My Creation',
      grassLight: grass,
      grassDark: shade(grass, 0.82),
      roadLight: road,
      roadDark: shade(road, 0.82),
      wood: wood,
      woodDark: shade(wood, 0.7),
      stone: stone,
      stoneDark: shade(stone, 0.72),
      accent: accent,
      accentDark: shade(accent, 0.72),
      text: const Color(0xFF2E2418),
      muted: const Color(0xFF6B5E49),
      card: c('card'),
      cardDeep: shade(c('card'), 0.88),
      creepBase: creep,
      creepBelly: shade(creep, 0.68),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Profile: prefer the master-rules JSON key; migrate every legacy key
    // once, then remove them for good.
    final raw = p.getString(_kProfileJson) ?? p.getString(_kLegacyProfileJson);
    if (raw != null) {
      playerName = decodeProfile(raw);
    } else {
      final legacyName = p.getString(_kLegacyName);
      playerName = decodeProfile(null, legacyName: legacyName);
    }
    await p.setString(_kProfileJson, encodeProfile(playerName));
    await p.remove(_kLegacyProfileJson);
    await p.remove(_kLegacyName);
    await p.remove(_kLegacyNames);
    themeId = p.getString(_kTheme) ?? 'meadow';
    towerStyle = (p.getInt(_kTowerStyle) ?? 0).clamp(0, 7);
    enemyStyle = (p.getInt(_kEnemyStyle) ?? 0).clamp(0, 7);
    mapStyle = (p.getInt(_kMapStyle) ?? 0).clamp(0, 7);
    difficulty = (p.getInt(_kDifficulty) ?? 0).clamp(0, 2);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    bestWave = p.getInt(_kBestWave) ?? 0;
    bestEndless = p.getInt(_kBestEndless) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    campaignWins = p.getInt(_kWins) ?? 0;
    totalKills = p.getInt(_kKills) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfileJson, encodeProfile(playerName));
    await p.setString(_kTheme, themeId);
    await p.setInt(_kTowerStyle, towerStyle);
    await p.setInt(_kEnemyStyle, enemyStyle);
    await p.setInt(_kMapStyle, mapStyle);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kMode, mode);
    await p.setInt(_kBestWave, bestWave);
    await p.setInt(_kBestEndless, bestEndless);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, campaignWins);
    await p.setInt(_kKills, totalKills);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || TDThemes.isProTheme(themeId)) {
      themeId = 'meadow';
      changed = true;
    }
    if (TowerStyles.isPro(towerStyle)) {
      towerStyle = 0;
      changed = true;
    }
    if (EnemyStyles.isPro(enemyStyle)) {
      enemyStyle = 0;
      changed = true;
    }
    if (MapStyles.isPro(mapStyle)) {
      mapStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // Legend is a Pro tier
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || TDThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setTowerStyle(int v) async {
    v = v.clamp(0, TowerStyles.names.length - 1);
    if (!isPro && TowerStyles.isPro(v)) return;
    towerStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setEnemyStyle(int v) async {
    v = v.clamp(0, EnemyStyles.names.length - 1);
    if (!isPro && EnemyStyles.isPro(v)) return;
    enemyStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMapStyle(int v) async {
    v = v.clamp(0, MapStyles.names.length - 1);
    if (!isPro && MapStyles.isPro(v)) return;
    mapStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  /// Record a finished game.
  Future<void> recordGame({
    required bool won,
    required int wave,
    required bool endless,
    required int kills,
  }) async {
    gamesPlayed++;
    totalKills += kills;
    if (endless) {
      if (wave > bestEndless) bestEndless = wave;
    } else {
      if (wave > bestWave) bestWave = wave;
      if (won) campaignWins++;
    }
    notifyListeners();
    await _save();
  }
}
