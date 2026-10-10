import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/td_themes.dart';

/// Tower Defense PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final TDAudio audio;
  final TDSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  TDThemeDef get _t => TDThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TDStyle.body(15, _t)),
        backgroundColor: _t.text,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
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
        title: Text('Tower Defense PRO', style: TDStyle.display(22, t)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              children: [
                                _TipsCard(
                  theme: t,
                  store: store,
                  audio: widget.audio,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _Cell extends StatelessWidget {
  final Object value; // bool | String
  final TDThemeDef theme;
  const _Cell({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: TDStyle.body(15,
            theme,
            color: v ? theme.accentDark : theme.muted),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: TDStyle.label(12, theme),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
class _TipsCard extends StatelessWidget {
  final TDThemeDef theme;
  final StoreService store;
  final TDAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.cardDeep.withValues(alpha: 0.6),
        border: Border.all(color: theme.accent, width: 2),
      ),
      child: Column(
        children: [
          Text('Tip the Maker', style: TDStyle.display(20, theme)),
          const SizedBox(height: 8),
          Text(
            'Tower Defense is free forever. A small tip keeps new games coming!',
            style: TDStyle.body(14, theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: TDStyle.body(13,
                  theme, color: theme.muted),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: TDStyle.body(13,
                    theme, color: theme.muted))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: theme,
                    label:
                        '${p.id == StoreService.chocolateId ? '🍫' : '☕'} ${p.price}',
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final TDThemeDef theme;
  final String label;
  final VoidCallback onTap;
  const _TipChip(
      {required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.06),
          border: Border.all(color: theme.accent, width: 1.5),
        ),
        child: Text(label, style: TDStyle.label(14, theme)),
      ),
    );
  }
}
