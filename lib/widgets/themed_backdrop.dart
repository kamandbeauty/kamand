import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Theme-driven backdrop behind every route of the app.
///
/// For the velvet-night skin (the design-reference look) it layers the
/// generated midnight-nebula artwork, full-bleed under the UI — the
/// skin's scaffold is transparent so it shows through. The UI itself
/// floats borderless on top (v1.10.2: the ornamental frame was removed
/// by design request; the artwork stays).
///
/// Other skins declare no asset, so this widget passes the child
/// through untouched (zero extra cost).
class ThemedBackdrop extends StatelessWidget {
  const ThemedBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).extension<SkyPalette>()?.backgroundAsset;
    if (asset == null) return child;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
        child,
      ],
    );
  }
}
