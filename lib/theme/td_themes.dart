import 'package:flutter/material.dart';

/// Theme, tower-style and enemy-style catalog for Tower Defense.
///
/// Art direction: a physical toy battlefield — wooden toy towers, chunky
/// stone ramparts, painted grass meadows, toy-like creeps. Every theme stays
/// inside that material world; variety comes from different meadows, woods,
/// stones and paint palettes. No neon, no cyberpunk, no AI-dashboard looks.
class TDThemeDef {
  final String id;
  final String name;
  final Color grassLight;
  final Color grassDark;
  final Color roadLight;
  final Color roadDark;
  final Color wood; // tower bodies
  final Color woodDark;
  final Color stone; // ramparts / castle
  final Color stoneDark;
  final Color accent; // UI highlights, bolts
  final Color accentDark;
  final Color text;
  final Color muted;
  final Color card; // panel background
  final Color cardDeep;
  final Color creepBase; // default creep paint
  final Color creepBelly;

  const TDThemeDef({
    required this.id,
    required this.name,
    required this.grassLight,
    required this.grassDark,
    required this.roadLight,
    required this.roadDark,
    required this.wood,
    required this.woodDark,
    required this.stone,
    required this.stoneDark,
    required this.accent,
    required this.accentDark,
    required this.text,
    required this.muted,
    required this.card,
    required this.cardDeep,
    required this.creepBase,
    required this.creepBelly,
  });
}

class TDThemes {
  /// First 4 are FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'meadow',
    'autumn',
    'snowy',
    'desert',
  ];

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';

  static TDThemeDef byId(String id, {TDThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static const List<TDThemeDef> all = [
    TDThemeDef(
      id: 'meadow',
      name: 'Green Meadow',
      grassLight: Color(0xFF9CCB6B),
      grassDark: Color(0xFF7BAF4E),
      roadLight: Color(0xFFE3C98F),
      roadDark: Color(0xFFC9A86B),
      wood: Color(0xFF9C6B3F),
      woodDark: Color(0xFF6E4826),
      stone: Color(0xFFB8B0A0),
      stoneDark: Color(0xFF847C6C),
      accent: Color(0xFFD97B2B),
      accentDark: Color(0xFF9E5416),
      text: Color(0xFF2E2418),
      muted: Color(0xFF6B5E49),
      card: Color(0xFFF3E9D2),
      cardDeep: Color(0xFFE0D0AC),
      creepBase: Color(0xFFB8452E),
      creepBelly: Color(0xFF7E2F1F),
    ),
    TDThemeDef(
      id: 'autumn',
      name: 'Autumn Orchard',
      grassLight: Color(0xFFD9A94E),
      grassDark: Color(0xFFB9853A),
      roadLight: Color(0xFFC9B18A),
      roadDark: Color(0xFFA68E68),
      wood: Color(0xFF8A5A30),
      woodDark: Color(0xFF5F3B1D),
      stone: Color(0xFFA8A094),
      stoneDark: Color(0xFF767064),
      accent: Color(0xFFB8452E),
      accentDark: Color(0xFF7E2F1F),
      text: Color(0xFF33231A),
      muted: Color(0xFF7A6450),
      card: Color(0xFFF6E8CE),
      cardDeep: Color(0xFFE2CC9E),
      creepBase: Color(0xFF7A3E8A),
      creepBelly: Color(0xFF522A5F),
    ),
    TDThemeDef(
      id: 'snowy',
      name: 'Snowy Pines',
      grassLight: Color(0xFFDDEAF2),
      grassDark: Color(0xFFBDD5E4),
      roadLight: Color(0xFFE8E4D8),
      roadDark: Color(0xFFC6C0AE),
      wood: Color(0xFF7C5A38),
      woodDark: Color(0xFF543C22),
      stone: Color(0xFF9BA4AE),
      stoneDark: Color(0xFF6E7883),
      accent: Color(0xFF2B7FA8),
      accentDark: Color(0xFF1B5A78),
      text: Color(0xFF22303A),
      muted: Color(0xFF62717C),
      card: Color(0xFFF0F4F8),
      cardDeep: Color(0xFFD6E0E8),
      creepBase: Color(0xFF3E7A8A),
      creepBelly: Color(0xFF2A5461),
    ),
    TDThemeDef(
      id: 'desert',
      name: 'Sandy Dunes',
      grassLight: Color(0xFFE8CD8F),
      grassDark: Color(0xFFD4AE66),
      roadLight: Color(0xFFC89B5E),
      roadDark: Color(0xFFA37A40),
      wood: Color(0xFF7A5230),
      woodDark: Color(0xFF523620),
      stone: Color(0xFFC2A37E),
      stoneDark: Color(0xFF8F7550),
      accent: Color(0xFFB85C1E),
      accentDark: Color(0xFF7F3E12),
      text: Color(0xFF3A2A18),
      muted: Color(0xFF7D6A4E),
      card: Color(0xFFF7ECD4),
      cardDeep: Color(0xFFE5D2A4),
      creepBase: Color(0xFF8A4E2E),
      creepBelly: Color(0xFF5F3420),
    ),
    TDThemeDef(
      id: 'twilight',
      name: 'Twilight Garden',
      grassLight: Color(0xFF6B8F5E),
      grassDark: Color(0xFF4F6D44),
      roadLight: Color(0xFF9C8FB8),
      roadDark: Color(0xFF7C6F94),
      wood: Color(0xFF5E3F52),
      woodDark: Color(0xFF3E2A38),
      stone: Color(0xFF8B8296),
      stoneDark: Color(0xFF615C6C),
      accent: Color(0xFFB87FC4),
      accentDark: Color(0xFF7E558A),
      text: Color(0xFF2C2333),
      muted: Color(0xFF6B6178),
      card: Color(0xFFD8CFE4),
      cardDeep: Color(0xFFB7AAC8),
      creepBase: Color(0xFF8A2E5E),
      creepBelly: Color(0xFF5F2041),
    ),
    TDThemeDef(
      id: 'harbor',
      name: 'Old Harbor',
      grassLight: Color(0xFF8FB8A4),
      grassDark: Color(0xFF6D9782),
      roadLight: Color(0xFFB8A888),
      roadDark: Color(0xFF94866A),
      wood: Color(0xFF6E4A2E),
      woodDark: Color(0xFF4A3018),
      stone: Color(0xFFA8A8A0),
      stoneDark: Color(0xFF7A7A70),
      accent: Color(0xFF2E8A7A),
      accentDark: Color(0xFF1E5F54),
      text: Color(0xFF1E2E28),
      muted: Color(0xFF5C6E64),
      card: Color(0xFFE8EFEA),
      cardDeep: Color(0xFFC2D4C8),
      creepBase: Color(0xFF2E5E8A),
      creepBelly: Color(0xFF20405F),
    ),
    TDThemeDef(
      id: 'volcano',
      name: 'Volcano Ridge',
      grassLight: Color(0xFF8A7A6E),
      grassDark: Color(0xFF6A5C52),
      roadLight: Color(0xFFB09A7E),
      roadDark: Color(0xFF8C7558),
      wood: Color(0xFF4E3428),
      woodDark: Color(0xFF33221A),
      stone: Color(0xFF6E6860),
      stoneDark: Color(0xFF4A4640),
      accent: Color(0xFFD94E2B),
      accentDark: Color(0xFF96331A),
      text: Color(0xFF2E1F18),
      muted: Color(0xFF6E5E52),
      card: Color(0xFFE0D0BE),
      cardDeep: Color(0xFFBCA88E),
      creepBase: Color(0xFFA83A2E),
      creepBelly: Color(0xFF752820),
    ),
    TDThemeDef(
      id: 'candy',
      name: 'Candy Fields',
      grassLight: Color(0xFFB8D98A),
      grassDark: Color(0xFF97BC6C),
      roadLight: Color(0xFFF2D8B8),
      roadDark: Color(0xFFD4AE86),
      wood: Color(0xFFB87FA8),
      woodDark: Color(0xFF845874),
      stone: Color(0xFFC8B8D8),
      stoneDark: Color(0xFF9686A6),
      accent: Color(0xFFD94E8A),
      accentDark: Color(0xFF96335E),
      text: Color(0xFF38222E),
      muted: Color(0xFF7D6470),
      card: Color(0xFFF6E8F2),
      cardDeep: Color(0xFFDDC4D8),
      creepBase: Color(0xFF8A4E9E),
      creepBelly: Color(0xFF5F356E),
    ),
    TDThemeDef(
      id: 'bamboo',
      name: 'Bamboo Grove',
      grassLight: Color(0xFFA8C46A),
      grassDark: Color(0xFF84A24C),
      roadLight: Color(0xFFD8C49A),
      roadDark: Color(0xFFB49C6E),
      wood: Color(0xFF9C7A3C),
      woodDark: Color(0xFF6E5426),
      stone: Color(0xFF9C948A),
      stoneDark: Color(0xFF6E6860),
      accent: Color(0xFFC43E2E),
      accentDark: Color(0xFF8A2A20),
      text: Color(0xFF2E2A1E),
      muted: Color(0xFF6E684E),
      card: Color(0xFFF0EAD6),
      cardDeep: Color(0xFFD4C8A8),
      creepBase: Color(0xFF4E8A2E),
      creepBelly: Color(0xFF356020),
    ),
    TDThemeDef(
      id: 'midnightoil',
      name: 'Lantern Night',
      grassLight: Color(0xFF4A5A48),
      grassDark: Color(0xFF35423A),
      roadLight: Color(0xFF8A7C60),
      roadDark: Color(0xFF6A5E48),
      wood: Color(0xFF5E4230),
      woodDark: Color(0xFF3E2C20),
      stone: Color(0xFF6E6E7A),
      stoneDark: Color(0xFF4A4A54),
      accent: Color(0xFFD9A42B),
      accentDark: Color(0xFF96701A),
      text: Color(0xFF232018),
      muted: Color(0xFF5E5A48),
      card: Color(0xFFD8D0B8),
      cardDeep: Color(0xFFB2A684),
      creepBase: Color(0xFF6E2E8A),
      creepBelly: Color(0xFF4A205F),
    ),
    TDThemeDef(
      id: 'riverstone',
      name: 'Riverstone',
      grassLight: Color(0xFF8FC4B8),
      grassDark: Color(0xFF6DA294),
      roadLight: Color(0xFFC8B89A),
      roadDark: Color(0xFFA49676),
      wood: Color(0xFF7A5C3A),
      woodDark: Color(0xFF543E26),
      stone: Color(0xFFA8B4B8),
      stoneDark: Color(0xFF788488),
      accent: Color(0xFF2B9ED9),
      accentDark: Color(0xFF1A6E97),
      text: Color(0xFF1E2E30),
      muted: Color(0xFF5C6E6E),
      card: Color(0xFFE4F0EE),
      cardDeep: Color(0xFFB8D4CE),
      creepBase: Color(0xFF2E6E8A),
      creepBelly: Color(0xFF204C61),
    ),
    TDThemeDef(
      id: 'emberwood',
      name: 'Emberwood',
      grassLight: Color(0xFFB87F4E),
      grassDark: Color(0xFF96613A),
      roadLight: Color(0xFF9C7A5A),
      roadDark: Color(0xFF7C5E42),
      wood: Color(0xFF4E2E20),
      woodDark: Color(0xFF331E14),
      stone: Color(0xFF847A72),
      stoneDark: Color(0xFF5C5450),
      accent: Color(0xFFE87B2B),
      accentDark: Color(0xFFA5541A),
      text: Color(0xFF2E201A),
      muted: Color(0xFF6E5E50),
      card: Color(0xFFE8D8C4),
      cardDeep: Color(0xFFC2AC90),
      creepBase: Color(0xFFB84E2B),
      creepBelly: Color(0xFF7F351D),
    ),
  ];
}

// ---------------------------------------------------------------------------
/// Cosmetic tower styles — paint/finish applied to all tower kinds.
/// First 4 FREE, the rest PRO.
class TowerStyles {
  static const List<String> names = [
    'Oakwood', // 0 free
    'Pinewood', // 1 free
    'Granite', // 2 free
    'Sandstone', // 3 free
    'Ironclad', // 4 pro
    'Royal Oak', // 5 pro
    'Mossy Stone', // 6 pro
    'Obsidian', // 7 pro
  ];
  static bool isPro(int i) => i >= 4;
}

/// Cosmetic map styles — the battlefield's dressing: grass dressing, road
/// width, checkerboard, flowers and pebbles. First 4 FREE, the rest PRO.
class MapStyles {
  static const List<String> names = [
    'Classic Meadow', // 0 free
    'Wild Grass', // 1 free
    'Clean Cut', // 2 free
    'Wide Road', // 3 free
    'Worn Path', // 4 pro
    'Stone Edging', // 5 pro
    'Flower Dots', // 6 pro
    'Pebble Path', // 7 pro
  ];
  static bool isPro(int i) => i >= 4;

  /// Cosmetic parameters the board painter consumes.
  static TDMapLook look(int i) {
    switch (i.clamp(0, 7)) {
      case 1:
        return const TDMapLook(tufts: 60, roadWidth: 1.0);
      case 2:
        return const TDMapLook(tufts: 0, roadWidth: 1.0, plain: true);
      case 3:
        return const TDMapLook(tufts: 20, roadWidth: 1.25);
      case 4:
        return const TDMapLook(tufts: 34, roadWidth: 0.78, patches: true);
      case 5:
        return const TDMapLook(tufts: 26, roadWidth: 1.0, edging: true);
      case 6:
        return const TDMapLook(tufts: 30, roadWidth: 1.0, flowers: true);
      case 7:
        return const TDMapLook(tufts: 22, roadWidth: 0.92, pebbles: true);
      default:
        return const TDMapLook();
    }
  }
}

class TDMapLook {
  final int tufts;
  final double roadWidth;
  final bool plain; // skip the mow checkerboard
  final bool patches; // worn patches beside the road
  final bool edging; // stone edging along the road
  final bool flowers;
  final bool pebbles;
  const TDMapLook({
    this.tufts = 26,
    this.roadWidth = 1.0,
    this.plain = false,
    this.patches = false,
    this.edging = false,
    this.flowers = false,
    this.pebbles = false,
  });
}

// ---------------------------------------------------------------------------
/// Display helpers: big display text, labels, body, and button styling.
class TDStyle {
  static TextStyle display(double size, TDThemeDef t,
          {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w800,
        color: color ?? t.text,
        letterSpacing: -0.5,
      );

  static TextStyle label(double size, TDThemeDef t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? t.accentDark,
        letterSpacing: 1.2,
      );

  static TextStyle body(double size, TDThemeDef t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? t.text,
      );

  static ButtonStyle primary(TDThemeDef t) => ElevatedButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      );

  static ButtonStyle soft(TDThemeDef t) => ElevatedButton.styleFrom(
        backgroundColor: t.card,
        foregroundColor: t.text,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      );
}
