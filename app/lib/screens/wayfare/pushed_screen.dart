import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';

/// Chrome for a screen pushed off a tab — currently Flights.
///
/// A pushed screen rather than a fifth tab: flights are used about twice per
/// trip, so a tab would spend a thumb slot permanently. Pushing also lets the
/// result hand back to the Trip tab, which is where the consequence lands.
///
/// No bottom nav here, deliberately — you are somewhere, not browsing.
class WayfarePushedScreen extends StatelessWidget {
  const WayfarePushedScreen({
    super.key,
    required this.title,
    required this.backLabel,
    required this.child,
    this.subtitle,
    this.onBack,
  });

  final String title;

  /// e.g. "Trip" — rendered as "‹ Trip" on iOS.
  final String backLabel;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final pop = onBack ?? () => Navigator.of(context).maybePop();

    return Scaffold(
      backgroundColor: WayfareColors.bgApp,
      body: Column(
        children: [
          theme.isAndroid ? _androidBar(context, pop) : _iosBar(context, pop),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _iosBar(BuildContext context, VoidCallback pop) {
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF0FFFDF9), // rgba(255,253,249,.94)
            border: Border(bottom: BorderSide(color: WayfareColors.borderSoft)),
          ),
          padding: EdgeInsets.fromLTRB(8, topInset > 0 ? topInset + 6 : 52, 8, 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Title is centred on the bar, not on the space left by the
              // back button, so it stays put as the label changes.
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: pop,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, WayfareTouch.ios),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_left,
                          size: 22, color: WayfareColors.accent),
                      Text(
                        backLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          color: WayfareColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _androidBar(BuildContext context, VoidCallback pop) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        color: WayfareColors.surface,
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 0),
        ],
      ),
      padding: EdgeInsets.fromLTRB(4, topInset + 8, 8, 12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: pop,
              tooltip: 'Back to $backLabel',
              icon: const Icon(Icons.arrow_back, size: 22, color: Color(0xFF4A4239)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WayfareColors.subhead,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
