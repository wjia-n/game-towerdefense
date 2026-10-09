# Tower Defense — RULES.md

The authoritative source of truth for Tower Defense (package
`com.gameswajiha.towerdefense`). If the implementation conflicts with this
document, fix the implementation.

## 1. Objective

Build toy towers along a winding dirt road to stop waves of toy-like creeps
from breaching the castle gate. Survive all 30 waves (Campaign) or hold as
long as possible (Endless Siege).

## 2. Setup

- 9×9 meadow grid. A fixed dirt road winds from the spawn portal (top-left)
  to the castle gate (bottom-right): cells
  (0,1)→(7,1)→(7,4)→(2,4)→(2,7)→(8,7).
- Starting resources by difficulty:
  - Recruit: 300 gold, 20 lives.
  - Defender: 250 gold, 15 lives.
  - Legend (PRO): 220 gold, 12 lives.
  - Endless adds +5 lives and +50 gold on any difficulty.
- One commander profile (renameable). Towers cost gold to place.

## 3. Turn order

Real-time, not turn-based:
1. Player presses **Start wave** → 2.2s intro banner → wave spawns.
2. Creeps spawn one-by-one along the road; towers fire automatically.
3. When the last creep is killed or breaches, the wave ends: bonus gold is
   banked, +2 lives every 5th wave, and the player starts the next wave.

## 4. Legal moves

- Place a tower on any empty grass cell (never on the road, never stacked).
- Upgrade a tower (Lv1→Lv2; Lv3 is PRO): +90% damage per level (Lv2 ×1.9,
  Lv3 ×2.8), +0.35 range per level. Cost = 80% of total invested.
- Sell a tower: refunds 70% of total invested.
- Towers may be placed/upgraded/sold at any time, including mid-wave.

## 5. Illegal moves

- Placing on the road, on an occupied cell, or off the board.
- Placing a tower you cannot afford.
- Placing/upgrading during pause, or after victory/defeat.
- Selecting a PRO tower kind without PRO (UI hides them behind the PRO
  screen).

## 6. Captures

N/A (no capture mechanic). Kills earn gold equal to the creep's reward.

## 7. Special rules

- **Targeting:** each tower fires at the creep closest to the castle gate
  within range.
- **Boss waves:** every 5th wave brings 1 boss (2 from wave 15) plus escorts.
- **Wave-clear bonus:** 25 + 3×wave gold; +2 lives every 5 waves (cap 30).
- **Creep abilities:** runners are fast, brutes are tough, shields ignore 45%
  of damage, bosses ignore 20% and cost 5 lives on breach.
- **Tower specials:** cannon/mortar deal splash damage; frost slows 50% for
  2.5s; tesla chains to 2 extra creeps; venom poisons (damage over time);
  ballista bolts pierce up to 3 creeps.
- **Determinism:** each game uses a seeded RNG; same seed + same inputs =
  same battle.

## 8. Scoring

- Gold is the currency; kills are the score.
- Lifetime stats: best campaign wave, best endless wave, campaigns won,
  total creeps defeated, games played.

## 9. Winning conditions

- Campaign: all 30 waves cleared with ≥1 life remaining → Victory.
- Endless: no victory; the run ends in defeat and the wave count is the score.

## 10. Draw conditions

N/A — every game ends in victory or defeat.

## 11. AI strategy

N/A — no AI opponent. Creep pathing is fixed along the road.

## 12. Edge cases

- Lives hit 0 mid-wave → immediate defeat; board freezes.
- A wave with all creeps dead and no bolts flying always completes (engine
  watchdog also enforces this every 3s).
- Selling the last tower mid-wave is legal — you may still win with zero
  towers only if no creeps remain (they will breach otherwise).
- Pausing freezes the simulation clock; resuming continues exactly.
- App backgrounding pauses the game and the music; both resume on return.
- Purchases restore via the store; PRO state persists across reinstalls of
  the profile.

## 13. Test cases

1. Start campaign → intro banner → wave 1 spawns and completes → bonus banked.
2. Place arrow tower on grass: gold decreases by 50, tower appears with
   build pop-in animation.
3. Attempt placement on road: rejected with invalid sound, no gold lost.
4. Upgrade tower: damage multiplier applies, level pip appears.
5. Sell tower: 70% of invested gold refunded.
6. Let a creep breach: lives decrease, breach banner + sound.
7. Lives → 0: defeat dialog with stats; Play again restarts cleanly.
8. Clear wave 30: victory dialog; review prompt may appear.
9. Pause → background → foreground: simulation and music resume.
10. Rename commander → restart app: name persists (single JSON string).
11. Free player opens PRO-locked theme/style/difficulty: redirected to PRO
    screen, nothing unlocks silently.
12. With no store products configured: PRO screen shows "Available after
    store setup", no fake buy buttons.
