import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/trip.dart';
import '../../../state/wayfare_controller.dart';
import '../formatting.dart';
import '../shell_chrome.dart';
import 'import_sheet.dart';

/// Everything imported into the trip, and the places it produced.
///
/// Imports used to disappear: a link went in through the chat, some number of
/// places came out, and nothing in the app ever showed them again. A planner
/// that claims to have read your references has to be able to show you what it
/// read — this is that page.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, required this.controller});

  final WayfareController controller;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  List<TripSource>? _sources;
  List<Place> _places = const [];
  String? _error;

  /// Which source's places are expanded. Only one at a time — the list is the
  /// index, and every card open at once is just the places list again.
  String? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await widget.controller.sources();
      final places = await widget.controller.places();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _places = places;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _import() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WayfareTheme(
        platform: WayfareTheme.of(context).platform,
        child: ImportLinkSheet(controller: widget.controller),
      ),
    );
    await _load();
  }

  Future<void> _remove(TripSource source) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove this import?',
      body: source.placeCount == 0
          ? 'Nothing came out of it, so nothing goes with it.'
          : 'The ${source.placeCount} '
              '${source.placeCount == 1 ? 'place' : 'places'} it found go too. '
              'Anything already in the itinerary stays where it is.',
      confirmLabel: 'Remove',
      cancelLabel: 'Keep it',
    );
    if (!confirmed) return;
    await widget.controller.removeSource(source.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WayfareColors.bgApp,
      body: Column(
        children: [
          WayfareHeader(
            overline: 'What the planner has read',
            title: 'Your references',
            subtitle: _subtitle(),
            actionIcon: Icons.add,
            actionLabel: 'Import a link',
            onAction: _import,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  String _subtitle() {
    final sources = _sources;
    if (sources == null) return 'Loading…';
    if (sources.isEmpty) return 'Nothing imported yet';
    final places = _places.length;
    return '${sources.length} ${sources.length == 1 ? 'source' : 'sources'} · '
        '$places ${places == 1 ? 'place' : 'places'}';
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: WayfareType.body(13.5, color: WayfareColors.subhead),
          ),
        ),
      );
    }

    final sources = _sources;
    if (sources == null) {
      return const Center(
        child: CircularProgressIndicator(color: WayfareColors.accent),
      );
    }

    if (sources.isEmpty) return _empty();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sources.length,
      separatorBuilder: (_, _) => const SizedBox(height: WayfareSpace.cardGap),
      itemBuilder: (context, i) {
        final source = sources[i];
        return _SourceCard(
          source: source,
          places: _places.where((p) => p.sourceId == source.id).toList(),
          expanded: _open == source.id,
          onToggle: () => setState(
            () => _open = _open == source.id ? null : source.id,
          ),
          onRemove: () => _remove(source),
          onPasteText: source.needsManualInput ? _import : null,
        );
      },
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nothing imported yet', style: WayfareType.display(24)),
            const SizedBox(height: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Paste a 小红书 post, a TripAdvisor list or a blog and the '
                'planner reads it before it plans anything. That is the point '
                'of it — you already found the places.',
                textAlign: TextAlign.center,
                style: WayfareType.body(13.5, color: WayfareColors.subhead),
              ),
            ),
            const SizedBox(height: 18),
            WayfarePrimaryButton(label: 'Import a link', onPressed: _import),
          ],
        ),
      ),
    );
  }
}

/// One import: where it came from, what came out, and the places themselves.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.places,
    required this.expanded,
    required this.onToggle,
    required this.onRemove,
    this.onPasteText,
  });

  final TripSource source;
  final List<Place> places;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  /// Only for a source whose fetch was blocked — the way to finish it.
  final VoidCallback? onPasteText;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final count = source.placeCount;

    return Material(
      color: WayfareColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: theme.cardLg,
        side: const BorderSide(color: WayfareColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: count > 0 ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 13, 8, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WayfareEyebrow(
                          _kindLabel(source.kind),
                          color: WayfareColors.accent,
                          size: 11.5,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          source.title ?? source.url ?? 'Pasted text',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _status(),
                          style: WayfareType.body(
                            12.5,
                            color: source.error != null
                                ? WayfareColors.destructiveInk
                                : WayfareColors.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: WayfareColors.mutedLight,
                    ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: onRemove,
                      tooltip: 'Remove this import',
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 19,
                        color: WayfareColors.removeIcon,
                      ),
                    ),
                  ),
                ],
              ),
              if (onPasteText != null) ...[
                const SizedBox(height: 8),
                WayfareSecondaryButton(
                  label: 'Paste the post text',
                  onPressed: onPasteText,
                  fontSize: 13,
                ),
              ],
              if (expanded && places.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final place in places)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7, right: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 6, right: 9),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: WayfareColors.mutedLight,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            place.name,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                        if (place.category != null)
                          Text(
                            categoryLabel(place.category!),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: WayfareColors.mutedLight,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _status() {
    if (source.error != null) return source.error!;
    if (source.needsManualInput) {
      return 'Blocked — it needs the post text pasted in';
    }
    final count = source.placeCount;
    if (count == 0) return 'Read, but no places came out of it';
    return '$count ${count == 1 ? 'place' : 'places'}';
  }

  static String _kindLabel(String kind) => switch (kind) {
        'xiaohongshu' => '小红书',
        'tripadvisor' => 'TripAdvisor',
        'manual' => 'Pasted',
        _ => 'Web',
      };
}
