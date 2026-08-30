import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'tokens.dart';

/// Ask before something irreversible happens.
///
/// Destructive actions in this app are *named* rather than labelled "Delete",
/// and they never get a red fill — the weight is carried by the copy, which
/// has to say what actually goes. Returns false if dismissed by tapping away,
/// so the safe answer is the default in every path.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: WayfareColors.surface,
      title: Text(title, style: WayfareType.display(20)),
      content: Text(
        body,
        style: WayfareType.body(13.5, color: WayfareColors.subhead),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: WayfareColors.inkSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: const TextStyle(color: WayfareColors.destructiveInk),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The grabber at the top of a bottom sheet.
///
/// Must sit *outside* the sheet's scroll view. Inside it, a downward drag on
/// the grabber scrolls the content instead of dismissing the sheet — which is
/// the one gesture everyone reaches for to close one.
class WayfareSheetGrabber extends StatelessWidget {
  const WayfareSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Full width and a real height, so the draggable target is the whole
      // top strip rather than the 4px bar people have to hit exactly.
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: WayfareColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Drag-to-dismiss for a sheet whose body scrolls.
///
/// `showModalBottomSheet`'s own drag loses the gesture arena to any scroll
/// view inside it, so at the top of a sheet the one gesture everyone reaches
/// for to close it does nothing. This watches raw pointers instead of entering
/// the arena: a downward drag moves the sheet when the body is already at the
/// top, or whenever it starts on the grabber, and is ignored while there is
/// still content above. The body scrolls with clamping physics so it cannot
/// bounce underneath the drag.
///
/// [builder] must attach the given controller to its scroll view and put a
/// [WayfareSheetGrabber] at the top of the card.
class WayfareDismissibleSheet extends StatefulWidget {
  const WayfareDismissibleSheet({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  @override
  State<WayfareDismissibleSheet> createState() =>
      _WayfareDismissibleSheetState();
}

class _WayfareDismissibleSheetState extends State<WayfareDismissibleSheet>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )
    ..addListener(() => setState(() {}))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _drag = 0;
    });

  /// How far the sheet has been pulled down, in logical pixels.
  double _drag = 0;
  double _snapFrom = 0;
  double _startY = 0;
  double _lastY = 0;
  Duration _lastAt = Duration.zero;
  double _velocity = 0;
  bool _tracking = false;

  /// Below this the drag springs back; past it the sheet closes.
  static const _closeAt = 96.0;
  static const _flingAt = 700.0;

  /// The grabber strip: 10 above the bar, the 4px bar, 12 below.
  static const _grabberHeight = 30.0;

  @override
  void dispose() {
    _snapBack.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _atTop => !_scroll.hasClients || _scroll.offset <= 0.5;

  void _down(PointerDownEvent event) {
    _snapBack.stop();
    _startY = event.position.dy;
    _lastY = _startY;
    _lastAt = event.timeStamp;
    _velocity = 0;
    // The grabber exists to close the sheet, so a drag starting there works
    // however far the body has been scrolled.
    _tracking = event.localPosition.dy <= _grabberHeight || _atTop;
  }

  void _move(PointerMoveEvent event) {
    // A drag that began mid-list becomes eligible the moment the list runs
    // out of scroll, rather than needing the finger lifted and put down.
    if (!_tracking) {
      if (!_atTop) return;
      _tracking = true;
      _startY = event.position.dy - _drag;
    }

    final elapsed = (event.timeStamp - _lastAt).inMicroseconds;
    if (elapsed > 0) {
      _velocity = (event.position.dy - _lastY) / elapsed * 1e6;
    }
    _lastY = event.position.dy;
    _lastAt = event.timeStamp;

    final next = event.position.dy - _startY;
    // Upward drags belong to the scroll view, not to us.
    if (next <= 0 && _drag == 0) return;
    setState(() => _drag = next.clamp(0.0, double.infinity));
  }

  void _up([PointerEvent? _]) {
    if (!_tracking) return;
    _tracking = false;
    if (_drag >= _closeAt || _velocity >= _flingAt) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_drag == 0) return;
    _snapFrom = _drag;
    _snapBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final offset = _snapBack.isAnimating
        ? _snapFrom * (1 - Curves.easeOutCubic.transform(_snapBack.value))
        : _drag;

    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Transform.translate(
        offset: Offset(0, offset),
        child: widget.builder(context, _scroll),
      ),
    );
  }
}

/// A brief message at the top of the screen.
///
/// Not a SnackBar: those are anchored to the bottom, where this app keeps its
/// navigation — so an explanation of why a tab is unavailable appeared on top
/// of the tab it was explaining. This comes down from the top, clear of
/// everything, and leaves on its own.
/// One at a time: tapping a dimmed tab four times shows one message, not four
/// stacked on top of each other. A repeat restarts the countdown, so the toast
/// stays up while it is still being provoked.
_ToastHandle? _liveToast;

void showWayfareToast(BuildContext context, String message) {
  final live = _liveToast;
  if (live != null && live.entry.mounted) {
    live.state.currentState?.refresh(message);
    return;
  }

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final key = GlobalKey<_WayfareToastState>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _WayfareToast(
      key: key,
      message: message,
      onFinished: () {
        if (entry.mounted) entry.remove();
        if (identical(_liveToast?.entry, entry)) _liveToast = null;
      },
    ),
  );
  _liveToast = _ToastHandle(entry, key);
  overlay.insert(entry);
}

class _ToastHandle {
  const _ToastHandle(this.entry, this.state);

  final OverlayEntry entry;
  final GlobalKey<_WayfareToastState> state;
}

class _WayfareToast extends StatefulWidget {
  const _WayfareToast({
    super.key,
    required this.message,
    required this.onFinished,
  });

  final String message;
  final VoidCallback onFinished;

  @override
  State<_WayfareToast> createState() => _WayfareToastState();
}

class _WayfareToastState extends State<_WayfareToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  static const _holdFor = Duration(milliseconds: 3000);

  late String _message = widget.message;
  Timer? _leave;

  @override
  void initState() {
    super.initState();
    _in.forward();
    _scheduleLeave();
  }

  void _scheduleLeave() {
    _leave?.cancel();
    _leave = Timer(_holdFor, () async {
      if (!mounted) return;
      await _in.reverse();
      if (mounted) widget.onFinished();
    });
  }

  /// A repeat tap while this is up: same toast, new words, fresh countdown.
  void refresh(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    _in.forward();
    _scheduleLeave();
  }

  @override
  void dispose() {
    _leave?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 14,
      right: 14,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(curved),
          child: Material(
            color: WayfareColors.ink,
            borderRadius: BorderRadius.circular(14),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Text(
                _message,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: WayfareColors.generatingInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 999-radius pill with a border — the OPTIONAL badge, conflict tags, pace
/// chips. Sizes vary per use, so they're parameters rather than variants.
class WayfarePill extends StatelessWidget {
  const WayfarePill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
    this.fontSize = 10.5,
    this.weight = FontWeight.w700,
    this.uppercase = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  /// The OPTIONAL badge on an activity card.
  factory WayfarePill.optional() => const WayfarePill(
        label: 'optional',
        background: WayfareColors.warningBg,
        foreground: WayfareColors.warningText,
        border: WayfareColors.warningBorder,
      );

  /// A conflict's category tag (Pace / Mobility / Food).
  factory WayfarePill.conflictTag(String tag) => WayfarePill(
        label: tag,
        background: WayfareColors.warningBg,
        foreground: WayfareColors.warningText,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      );

  /// Written by hand rather than planned.
  ///
  /// Sits in the card's existing pill row beside OPTIONAL — the only change a
  /// hand-written activity makes to the card, so it stays pixel-identical to a
  /// generated one everywhere else.
  factory WayfarePill.yours() => const WayfarePill(
        label: 'yours',
        background: WayfareColors.writtenBg,
        foreground: WayfareColors.writtenInk,
        border: WayfareColors.writtenPinBorder,
      );

  /// A traveller's pace, on the Group tab.
  factory WayfarePill.pace(String pace) => WayfarePill(
        label: pace,
        background: WayfareColors.paceChipBg,
        foreground: WayfareColors.inkSecondary,
        fontSize: 10.5,
        weight: FontWeight.w600,
        uppercase: false,
      );

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final double fontSize;
  final FontWeight weight;
  final bool uppercase;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: foreground,
          letterSpacing: uppercase ? fontSize * 0.06 : null,
        ),
      ),
    );
  }
}

/// A circular member avatar with white initials on the member's colour.
class WayfareAvatar extends StatelessWidget {
  const WayfareAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 24,
    this.ringWidth = 2,
    this.fontSize,
  });

  final String initials;
  final Color color;
  final double size;
  final double ringWidth;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ringWidth > 0
            ? Border.all(color: WayfareColors.surface, width: ringWidth)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize ?? size * 0.42,
          fontWeight: FontWeight.w700,
          color: WayfareColors.surface,
        ),
      ),
    );
  }
}

/// Overlapping avatar row (`margin-left: -5px` in the spec, -6 on conflicts).
class WayfareAvatarStack extends StatelessWidget {
  const WayfareAvatarStack({
    super.key,
    required this.avatars,
    this.size = 24,
    this.overlap = 5,
  });

  final List<({String initials, Color color})> avatars;
  final double size;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();

    // Each avatar after the first tucks under the previous one. Padding can't
    // be negative in Flutter, so the row is laid out at its overlapped width
    // and each child is shifted left by the overlap amount.
    final width = size + (avatars.length - 1) * (size - overlap);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < avatars.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: WayfareAvatar(
                initials: avatars[i].initials,
                color: avatars[i].color,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

/// The dark primary button: near-black fill, white text.
class WayfarePrimaryButton extends StatelessWidget {
  const WayfarePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.minHeight = 48,
    this.fontSize = 15,
    this.weight = FontWeight.w600,
  });

  final String label;

  /// Null disables the button, which renders at the spec's reduced opacity.
  final VoidCallback? onPressed;
  final double minHeight;
  final double fontSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: WayfareColors.ink,
        borderRadius: theme.pill,
        child: InkWell(
          onTap: onPressed,
          borderRadius: theme.pill,
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: weight,
                color: WayfareColors.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined secondary button ("Add traveller", "Hide optional activities").
class WayfareSecondaryButton extends StatelessWidget {
  const WayfareSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.minHeight = 48,
    this.fontSize = 14.5,
    this.background = Colors.transparent,
    this.foreground = WayfareColors.ink,
    this.weight = FontWeight.w500,
  });

  final String label;
  final VoidCallback? onPressed;
  final double minHeight;
  final double fontSize;
  final Color background;
  final Color foreground;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Material(
      color: background,
      borderRadius: theme.pill,
      child: InkWell(
        onTap: onPressed,
        borderRadius: theme.pill,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: theme.pill,
            border: Border.all(color: WayfareColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// A surface card: cream fill, hairline border, large radius.
class WayfareCard extends StatelessWidget {
  const WayfareCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.background = WayfareColors.surface,
    this.border = WayfareColors.borderSoft,
    this.large = true,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color background;
  final Color? border;

  /// Large radius (`radiusLg`) for sections; the smaller `radius` for inner
  /// panels like an activity card or the resolution box.
  final bool large;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final radius = large ? theme.cardLg : theme.card;

    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: clip ? null : padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: clip ? child : child,
    );
  }
}

/// Section eyebrow: "BY CATEGORY", "WHERE YOU DIFFER".
class WayfareEyebrow extends StatelessWidget {
  const WayfareEyebrow(
    this.text, {
    super.key,
    this.color = WayfareColors.muted,
    this.size = 11.5,
  });

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: size * 0.07,
      ),
    );
  }
}

/// A rounded progress bar. Used for the budget hero and the per-category bars.
class WayfareBar extends StatelessWidget {
  const WayfareBar({
    super.key,
    required this.fraction,
    required this.fill,
    required this.track,
    this.height = 9,
  });

  /// 0–1; values above 1 are clamped, matching the spec's capped bar.
  final double fraction;
  final Color fill;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
          child: Container(color: fill),
        ),
      ),
    );
  }
}

/// The three staggered pulsing dots — the chat thinking indicator and the
/// generating overlay both use this, at different sizes and colours.
class WayfarePulsingDots extends StatefulWidget {
  const WayfarePulsingDots({
    super.key,
    required this.colors,
    this.size = 7,
    this.gap = 6,
    this.period = const Duration(milliseconds: 1000),
    this.stagger = const [0.0, 0.15, 0.3],
  });

  final List<Color> colors;
  final double size;
  final double gap;
  final Duration period;

  /// Delay per dot as a fraction of [period], matching the CSS animation-delay.
  final List<double> stagger;

  @override
  State<WayfarePulsingDots> createState() => _WayfarePulsingDotsState();
}

class _WayfarePulsingDotsState extends State<WayfarePulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.colors.length; i++) ...[
              if (i > 0) SizedBox(width: widget.gap),
              _dot(i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    final offset = widget.stagger.length > index ? widget.stagger[index] : 0.0;
    final t = (_controller.value + offset) % 1.0;
    // wp-pulse: opacity .35→1, scale .86→1, peaking at 50%.
    final wave = 1 - (2 * t - 1).abs();
    final opacity = 0.35 + 0.65 * wave;
    final scale = 0.86 + 0.14 * wave;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.colors[index],
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Text field styled to the sheet/composer spec: 16px to stop iOS zoom-on-focus,
/// 48px min height, alt surface fill.
class WayfareTextField extends StatelessWidget {
  const WayfareTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.onChanged,
    this.pillShaped = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool pillShaped;
  final bool autofocus;
  final int maxLines;
  final TextCapitalization textCapitalization;

  /// Constrain input at the keyboard rather than rejecting it afterwards —
  /// used for things with a known shape, like a flight number.
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final radius = pillShaped ? BorderRadius.circular(999) : theme.card;

    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      autofocus: autofocus,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      // 16px prevents iOS Safari-style zoom and matches the spec exactly.
      style: const TextStyle(fontSize: 16, color: WayfareColors.ink),
      cursorColor: WayfareColors.ink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: WayfareColors.mutedLight),
        filled: true,
        fillColor: WayfareColors.surfaceAlt,
        constraints: const BoxConstraints(minHeight: WayfareTouch.input),
        contentPadding:
            EdgeInsets.symmetric(horizontal: pillShaped ? 16 : 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: WayfareColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: WayfareColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: WayfareColors.info, width: 2),
        ),
      ),
    );
  }
}

/// A selectable chip — interests in the sheet, suggestions in the composer.
class WayfareSelectChip extends StatelessWidget {
  const WayfareSelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minHeight = 44,
    this.fontSize = 13,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return Material(
      color: selected ? WayfareColors.ink : WayfareColors.surfaceAlt,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? WayfareColors.ink : WayfareColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: selected ? WayfareColors.surface : WayfareColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
