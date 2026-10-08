import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const TowerDefenseApp());

class TowerDefenseApp extends StatelessWidget {
  const TowerDefenseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Tower Defense',
      tagline: 'Hold the castle. Twenty waves of baddies incoming!',
      emoji: '🗼',
      slug: 'towerdefense',
      howToPlay: '• Tap an empty grass cell, pick a tower, and place it\n• Towers zap creeps marching along the road\n• Earn gold per kill, upgrade or sell towers anytime\n• Survive all 20 waves — don\'t let them breach!',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => TowerDefenseScreen(players: players, callbacks: cb),
    );
  }
}
