import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/plan.dart';
import '../../../models/trip.dart';
import '../../../state/wayfare_controller.dart';
import '../formatting.dart';
import '../itinerary/activity_sheets.dart' show SheetFrame;

/// The places you saved that the plan did not use.
///
/// Each can go onto the day you are looking at, in the part of the day you
/// pick, and keeps its source on the card it becomes — so a card's "From …"
/// line stays true of everything that came from a link, whoever put it in the
/// plan.
class HeldBackSheet extends StatelessWidget {
  const HeldBackSheet({super.key, required this.controller, required this.day});

  final WayfareController controller;

  /// The day an added place lands on: the one on screen when this opened.
  final int day;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final places = controller.heldBackPlaces;
        return SheetFrame(
          children: [
            const WayfareEyebrow('From your links', color: WayfareColors.accent, size: 10.5),
            const SizedBox(height: 6),
            Text('Not in this plan', style: WayfareType.display(24)),
            const SizedBox(height: 6),
            Text(
              places.isEmpty
                  ? 'Everything you saved is in the plan now.'
                  : 'Places you saved that the plan didn’t use. Add any '
                      'of them to Day $day.',
              style: WayfareType.body(13.5, color: WayfareColors.subhead),
            ),
            const SizedBox(height: 14),
            for (final place in places) ...[
              _HeldBackRow(
                key: ValueKey(place.id),
                place: place,
                sourceTitle: place.sourceId == null
                    ? null
                    : controller.sourceTitles[place.sourceId],
                busy: controller.savingActivity,
                onAdd: (slot) async {
                  await controller.addSavedPlace(place, day, slot);
                  if (context.mounted && controller.error == null) {
                    showWayfareToast(context, 'Added ${place.name} to Day $day');
                  }
                },
              ),
              const SizedBox(height: WayfareSpace.cardGap),
            ],
          ],
        );
      },
    );
  }
}

/// One held-back place. "Add" opens the parts of the day to put it in, rather
/// than guessing one: whether a market is a morning or an evening is the
/// traveller's call.
class _HeldBackRow extends StatefulWidget {
  const _HeldBackRow({
    super.key,
    required this.place,
    required this.sourceTitle,
    required this.busy,
    required this.onAdd,
  });

  final Place place;
  final String? sourceTitle;
  final bool busy;
  final ValueChanged<TimeOfDay> onAdd;

  @override
  State<_HeldBackRow> createState() => _HeldBackRowState();
}

class _HeldBackRowState extends State<_HeldBackRow> {
  bool _choosing = false;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final place = widget.place;
    final meta = [
      // Leads its line here, so it is capitalised; the Sources screen's
      // trailing tag keeps the label's own lower case.
      if (place.category != null) _capitalised(categoryLabel(place.category!)),
      if ((place.why ?? '').trim().isNotEmpty) place.why!.trim(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: WayfareColors.bgApp,
        borderRadius: theme.card,
        border: Border.all(color: const Color(0xFFEAE0D0), width: 1.5),
      ),
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
                    Text(
                      place.name,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: WayfareColors.mutedLight),
                      ),
                    ],
                    if (widget.sourceTitle != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.link, size: 13, color: WayfareColors.accent),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'From ${widget.sourceTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: WayfareColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!_choosing)
                TextButton(
                  onPressed: widget.busy ? null : () => setState(() => _choosing = true),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      color: WayfareColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          // Grows open under the place rather than replacing it, so what is
          // being added stays readable while choosing where.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_choosing
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final slot in const [
                          TimeOfDay.morning,
                          TimeOfDay.afternoon,
                          TimeOfDay.evening,
                        ])
                          WayfareSelectChip(
                            label: _slotLabel(slot),
                            selected: false,
                            onTap: widget.busy ? () {} : () => widget.onAdd(slot),
                          ),
                        TextButton(
                          onPressed: () => setState(() => _choosing = false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: WayfareColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _slotLabel(TimeOfDay slot) => _capitalised(slot.name);
}

String _capitalised(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// The quiet line at the foot of a day: how many saved places the plan left
/// out, and the way to them. Trip-wide, but it lives at the bottom of each
/// day rather than above it — it is worth knowing, not worth leading with.
class HeldBackLine extends StatelessWidget {
  const HeldBackLine({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? '1 place you saved isn’t in this plan'
        : '$count places you saved aren’t in this plan';

    return Semantics(
      button: true,
      label: '$label. Show them.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.bookmark_border, size: 16, color: WayfareColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13.5, color: WayfareColors.muted),
                ),
              ),
              const Text(
                'Show',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: WayfareColors.accent,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: WayfareColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
