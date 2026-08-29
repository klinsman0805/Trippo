import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../api/api_client.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/trip.dart';
import '../../../state/wayfare_controller.dart';

/// Paste a link; get the places out of it.
///
/// This is the app's whole argument in one sheet — you already found the
/// places on 小红书 or a blog, and typing them in again is the work the app
/// exists to remove. So it is a first-class entry point rather than a chip in
/// the chat composer, and it says what it found rather than returning silently
/// to the itinerary.
class ImportLinkSheet extends StatefulWidget {
  const ImportLinkSheet({
    super.key,
    required this.controller,
    this.onDone,
  });

  final WayfareController controller;

  /// Called after a successful import, so the screen behind can refresh.
  final VoidCallback? onDone;

  @override
  State<ImportLinkSheet> createState() => _ImportLinkSheetState();
}

class _ImportLinkSheetState extends State<ImportLinkSheet> {
  final _input = TextEditingController();

  bool _working = false;
  String? _error;

  /// Set when the fetch was blocked and the post's text has to be pasted
  /// instead — 小红书 and Instagram both refuse a plain fetch.
  String? _awaitingTextFor;

  /// Set once something came back, so the sheet can say what it found.
  ImportResult? _result;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _canSubmit => _input.text.trim().length > 3 && !_working;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final value = _input.text.trim();
      final result = _awaitingTextFor != null
          ? await widget.controller
              .importPastedText(value, sourceId: _awaitingTextFor)
          : await widget.controller.importLink(value);

      if (!mounted) return;
      if (result.manualInputRequired) {
        // Not a failure: the link was stored, and the post's own text is the
        // one thing we cannot fetch ourselves.
        setState(() {
          _working = false;
          _awaitingTextFor = result.source.id;
          _input.clear();
        });
        return;
      }

      setState(() {
        _working = false;
        _result = result;
      });
      widget.onDone?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return WayfareDismissibleSheet(
      builder: (context, scrollController) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: WayfareColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.sheetRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WayfareSheetGrabber(),
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    28 + viewInsets + safeBottom,
                  ),
                  child: _result != null ? _found(_result!) : _form(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final pasting = _awaitingTextFor != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pasting ? 'Paste the post itself' : 'Start from a link',
          style: WayfareType.display(26),
        ),
        const SizedBox(height: 8),
        Text(
          pasting
              ? 'That site will not hand its posts to anyone but a browser. '
                  'Open it, copy the caption and comments, and paste them here '
                  '— the places come out of the text either way.'
              : 'A 小红书 post, a TripAdvisor list, a blog — anything with '
                  'places in it. We read it and pull them out, so you do not '
                  'type them in again.',
          style: WayfareType.body(13.5, color: WayfareColors.subhead),
        ),
        const SizedBox(height: 16),
        WayfareTextField(
          controller: _input,
          hint: pasting
              ? 'Paste the post text here…'
              : 'https://…  or the share text from the app',
          autofocus: true,
          maxLines: pasting ? 6 : 3,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _Notice(text: _error!, destructive: true),
        ],
        const SizedBox(height: 16),
        WayfarePrimaryButton(
          label: _working
              ? 'Reading it…'
              : pasting
                  ? 'Pull the places out'
                  : 'Import',
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: 8),
        WayfareSecondaryButton(
          label: 'Not now',
          onPressed: () => Navigator.of(context).pop(),
          background: Colors.transparent,
          foreground: WayfareColors.muted,
          fontSize: 13.5,
        ),
      ],
    );
  }

  /// What came back, stated as a count. A silent return to the itinerary is
  /// the one outcome that would make the import feel like it did nothing.
  Widget _found(ImportResult result) {
    final count = result.places.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count == 0
              ? 'Nothing to pull out of that one'
              : '$count ${count == 1 ? 'place' : 'places'} from this one',
          style: WayfareType.display(26),
        ),
        if (result.source.title != null) ...[
          const SizedBox(height: 6),
          Text(
            result.source.title!,
            style: WayfareType.body(13.5, color: WayfareColors.subhead),
          ),
        ],
        if (result.summary != null) ...[
          const SizedBox(height: 12),
          _Notice(text: result.summary!),
        ],
        if (count > 0) ...[
          const SizedBox(height: 16),
          for (final place in result.places.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlaceLine(place: place),
            ),
          if (count > 8)
            Text(
              'and ${count - 8} more',
              style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
            ),
        ],
        const SizedBox(height: 18),
        WayfarePrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 8),
        WayfareSecondaryButton(
          label: 'Import another',
          onPressed: () => setState(() {
            _result = null;
            _awaitingTextFor = null;
            _input.clear();
          }),
          background: Colors.transparent,
          foreground: WayfareColors.muted,
          fontSize: 13.5,
        ),
      ],
    );
  }
}

/// One extracted place: what it is, and why the post named it.
class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: WayfareColors.surfaceAlt,
        borderRadius: theme.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (place.category != null)
                Text(
                  place.category!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: WayfareColors.mutedLight,
                  ),
                ),
            ],
          ),
          if ((place.why ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              place.why!,
              style: WayfareType.body(12.5, color: WayfareColors.subhead),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.destructive = false});

  final String text;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: destructive ? WayfareColors.overBg : WayfareColors.infoBgAlt,
        borderRadius: theme.card,
        border: Border.all(
          color:
              destructive ? WayfareColors.overBg : WayfareColors.infoBorderAlt,
        ),
      ),
      child: Text(
        text,
        style: WayfareType.body(
          13,
          color: destructive
              ? WayfareColors.destructiveInk
              : WayfareColors.infoText,
        ),
      ),
    );
  }
}
