import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/wayfare_controller.dart';

/// Header, in whichever platform dress is active.
///
/// iOS: terracotta overline, 32px serif title, 44px circular action button.
/// Android: M3 top app bar, 20px/500 title over a 12.5px subtitle.
class WayfareHeader extends StatelessWidget {
  const WayfareHeader({
    super.key,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    this.onBack,
    this.secondaryActionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String overline;
  final String title;
  final String subtitle;

  /// The handoff spells this as a glyph (`+` / `↻` / `⋯`), but it also says to
  /// use the codebase's icon set for iconography — an icon renders reliably
  /// across platforms where a bare character can fall back to tofu.
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  /// Back to the trip list. Null when this shell is the root — showing a back
  /// button with nowhere to go is worse than showing none.
  final VoidCallback? onBack;

  /// An optional second action, sitting left of the first. Adding lives here
  /// rather than at the end of the day's scroll, where it moved further away
  /// the more there was to add to.
  final IconData? secondaryActionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return WayfareTheme.of(context).isAndroid ? _android(context) : _ios(context);
  }

  Widget _ios(BuildContext context) {
    // 56px top padding in the spec is the status-bar allowance; on a real
    // device the inset is authoritative, so take whichever is larger.
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      color: WayfareColors.bgApp,
      padding: EdgeInsets.fromLTRB(20, topInset > 0 ? topInset + 8 : 56, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) _BackLink(onPressed: onBack!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      overline.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.26,
                        color: WayfareColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WayfareType.display(32, height: 1.08)
                          .copyWith(letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (secondaryActionIcon != null) ...[
                _CircleActionButton(
                  icon: secondaryActionIcon!,
                  label: secondaryActionLabel ?? '',
                  onPressed: onSecondaryAction ?? () {},
                ),
                const SizedBox(width: 8),
              ],
              _CircleActionButton(
                icon: actionIcon,
                label: actionLabel,
                onPressed: onAction,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13.5, color: WayfareColors.subhead),
          ),
        ],
      ),
    );
  }

  Widget _android(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        color: WayfareColors.surface,
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 0),
        ],
      ),
      padding: EdgeInsets.fromLTRB(18, topInset + 10, 8, 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            if (onBack != null)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back to your trips',
                  icon: const Icon(Icons.arrow_back, size: 22),
                ),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WayfareColors.subhead,
                    ),
                  ),
                ],
              ),
            ),
            if (secondaryActionIcon != null)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: onSecondaryAction,
                  tooltip: secondaryActionLabel,
                  icon: Icon(secondaryActionIcon,
                      size: 22, color: const Color(0xFF4A4239)),
                ),
              ),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: onAction,
                tooltip: actionLabel,
                icon: Icon(actionIcon, size: 22, color: const Color(0xFF4A4239)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS back affordance: a text link in the accent colour, matching the pushed
/// screens' `‹ Trip` rather than inventing a second back idiom.
class _BackLink extends StatelessWidget {
  const _BackLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Back to your trips',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.chevron_left, size: 20, color: WayfareColors.accent),
                Text(
                  'Your trips',
                  style: TextStyle(
                    fontSize: 16,
                    color: WayfareColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: WayfareColors.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: const Color(0x1F000000),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(icon, size: 20, color: WayfareColors.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation. iOS is a translucent blurred bar; Android is an M3 bar
/// with a pill indicator behind the active icon.
class WayfareNavBar extends StatelessWidget {
  const WayfareNavBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final WayfareTab current;
  final ValueChanged<WayfareTab> onSelect;

  static const _items = <(WayfareTab, String, IconData)>[
    (WayfareTab.itinerary, 'Trip', Icons.map_outlined),
    (WayfareTab.budget, 'Budget', Icons.pie_chart_outline),
    (WayfareTab.group, 'Group', Icons.people_outline),
    (WayfareTab.chat, 'Refine', Icons.auto_awesome_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    return theme.isAndroid ? _android(context) : _ios(context);
  }

  Widget _ios(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF0FFFDF9), // rgba(255,253,249,.94)
            border: Border(top: BorderSide(color: WayfareColors.borderSoft)),
          ),
          // 30px in the spec is the home-indicator allowance.
          padding: EdgeInsets.fromLTRB(6, 8, 6, bottomInset > 0 ? bottomInset : 30),
          child: Row(
            children: [
              for (final (tab, label, icon) in _items)
                Expanded(
                  child: _NavItem(
                    label: label,
                    icon: icon,
                    active: tab == current,
                    activeColor: WayfareColors.accent,
                    onTap: () => onSelect(tab),
                    iconSize: 20,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    minHeight: 44,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _android(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: WayfareColors.androidNavBg,
        border: Border(top: BorderSide(color: WayfareColors.androidNavBorder)),
      ),
      padding: EdgeInsets.fromLTRB(4, 10, 4, 14 + bottomInset),
      child: Row(
        children: [
          for (final (tab, label, icon) in _items)
            Expanded(
              child: _NavItem(
                label: label,
                icon: icon,
                active: tab == current,
                activeColor: WayfareColors.androidActiveInk,
                onTap: () => onSelect(tab),
                iconSize: 18,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                minHeight: 52,
                pillIndicator: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    required this.iconSize,
    required this.fontSize,
    required this.fontWeight,
    required this.minHeight,
    this.pillIndicator = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final double minHeight;
  final bool pillIndicator;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : WayfareColors.faint;

    final iconWidget = Icon(icon, size: iconSize + 4, color: color);

    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pillIndicator)
                Container(
                  width: 60,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? WayfareColors.androidPill : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: iconWidget,
                )
              else
                iconWidget,
              SizedBox(height: pillIndicator ? 4 : 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: color,
                  letterSpacing: pillIndicator ? 0.02 : 0.01,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
