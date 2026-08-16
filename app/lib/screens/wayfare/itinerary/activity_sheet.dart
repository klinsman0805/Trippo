import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/plan.dart';
import '../formatting.dart';
import '../platform_pickers.dart';

/// Adding or editing one activity — the same sheet either way.
///
/// The form is longer than anyone wants to meet up front, so it opens on the
/// four fields people actually fill (part of the day, what it is, an optional
/// time, where) and hides the rest behind one disclosure. Editing opens it
/// expanded, because by then you know what you are looking for.
///
/// **A title is enough.** Everything else is optional, and a one-line activity
/// renders as a complete card rather than a stub — which is what makes typing
/// six things in a row feasible.
class ActivitySheet extends StatefulWidget {
  const ActivitySheet({
    super.key,
    required this.day,
    required this.onSave,
    required this.onCancel,
    this.existing,
    this.onRemove,
    this.initialSlot = TimeOfDay.anytime,
  });

  /// Which day this lands on — named on the CTA so it cannot be mistaken.
  final int day;

  /// The activity being edited. Null adds a new one.
  final PlanBlock? existing;

  final TimeOfDay initialSlot;

  /// Receives the wire-shaped payload for the block routes.
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onCancel;

  /// Only offered when editing.
  final VoidCallback? onRemove;

  @override
  State<ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<ActivitySheet> {
  late final TextEditingController _title;
  late final TextEditingController _venue;
  late final TextEditingController _description;
  late final TextEditingController _cost;
  late final TextEditingController _duration;
  late final TextEditingController _weather;

  late TimeOfDay _slot;
  String? _startTime;
  late bool _optional;

  /// Editing opens expanded; adding opens collapsed. Both because of what the
  /// user already knows at that moment.
  late bool _moreOpen;

  bool get _isEditing => widget.existing != null;

  static const _durationChips = <({String label, int minutes})>[
    (label: '30m', minutes: 30),
    (label: '1h', minutes: 60),
    (label: '1h 30m', minutes: 90),
    (label: '2h', minutes: 120),
    (label: '3h+', minutes: 180),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _title = TextEditingController(text: existing?.activity ?? '');
    _venue = TextEditingController(text: existing?.location ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _cost = TextEditingController(
      text: existing?.estimatedCostPerPerson?.round().toString() ?? '',
    );
    _duration = TextEditingController(
      text: existing?.estimatedDurationMinutes?.round().toString() ?? '',
    );
    _weather = TextEditingController(text: existing?.weatherBackup ?? '');

    _slot = existing?.timeOfDay ?? widget.initialSlot;
    _startTime = existing?.startTime;
    _optional = existing?.optional ?? false;
    _moreOpen = _isEditing;

    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _description.dispose();
    _cost.dispose();
    _duration.dispose();
    _weather.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;

    final minutes = int.tryParse(_duration.text.trim());
    final cost = num.tryParse(_cost.text.trim());

    widget.onSave({
      'activity': _title.text.trim(),
      'time_of_day': timeOfDayTo(_slot),
      'description': _description.text.trim(),
      'location': _venue.text.trim(),
      'start_time': _startTime,
      'estimated_duration_minutes': minutes,
      'estimated_cost_per_person': cost,
      'optional': _optional,
      'weather_backup':
          _weather.text.trim().isEmpty ? null : _weather.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    // No Align: showModalBottomSheet already docks this to the bottom, and
    // filling the screen meant every tap above the card landed on a
    // transparent area instead of the barrier — leaving no way out but the
    // buttons.
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: WayfareColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(theme.sheetRadius)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                offset: Offset(0, -12),
                blurRadius: 40,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 46 + viewInsets),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4, bottom: 14),
                    decoration: BoxDecoration(
                      color: WayfareColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (_isEditing) _identityHeader(context) else _addHeader(),
                const SizedBox(height: 16),
                if (_isEditing) ...[
                  _pinExplainer(theme),
                  const SizedBox(height: 15),
                ],
                _label('Part of the day'),
                _slotGrid(),
                const SizedBox(height: 15),
                _label('What is it'),
                WayfareTextField(
                  controller: _title,
                  hint: 'e.g. Hawker dinner at New Lane',
                  autofocus: !_isEditing,
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Start time · optional'),
                          _TimeField(
                            value: _startTime,
                            onChanged: (v) => setState(() => _startTime = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _label('Venue'),
                WayfareTextField(
                  controller: _venue,
                  hint: 'Place, address or neighbourhood',
                ),
                const SizedBox(height: 15),
                if (!_moreOpen)
                  WayfareSecondaryButton(
                    label: 'Add description, duration, cost',
                    onPressed: () => setState(() => _moreOpen = true),
                    minHeight: WayfareTouch.ios,
                    fontSize: 13.5,
                    foreground: WayfareColors.inkSecondary,
                  )
                else
                  _moreFields(theme),
                const SizedBox(height: 16),
                WayfarePrimaryButton(
                  label: _isEditing
                      ? 'Save changes'
                      : 'Add to day ${widget.day}',
                  onPressed: _canSave ? _save : null,
                  minHeight: WayfareTouch.sheetCta,
                  fontSize: 15.5,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 10),
                  Text(
                    'A title is enough. You can fill the rest in later.',
                    textAlign: TextAlign.center,
                    style: WayfareType.body(
                      12.5,
                      color: WayfareColors.mutedLight,
                    ),
                  ),
                ],
                if (_isEditing && widget.onRemove != null) ...[
                  const SizedBox(height: 10),
                  _RemoveButton(
                    day: widget.day,
                    onRemove: widget.onRemove!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addHeader() => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Add an activity', style: WayfareType.display(24)),
          const Spacer(),
          _cancelButton(),
        ],
      );

  Widget _identityHeader(BuildContext context) {
    final block = widget.existing!;
    final provenance = block.isMine
        ? 'You added this · ${block.timeOfDay.name}, day ${widget.day}'
        : 'Planned · ${block.timeOfDay.name}, day ${widget.day}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: WayfareColors.writtenBg,
            shape: BoxShape.circle,
            border: Border.all(color: WayfareColors.writtenBorder),
          ),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: timeOfDayColor(block.timeOfDay),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.activity,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WayfareType.display(22),
              ),
              Text(
                provenance,
                style: const TextStyle(
                  fontSize: 12,
                  color: WayfareColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
        _cancelButton(),
      ],
    );
  }

  Widget _cancelButton() => TextButton(
        onPressed: widget.onCancel,
        child: const Text(
          'Cancel',
          style: TextStyle(fontSize: 14, color: WayfareColors.mutedLight),
        ),
      );

  Widget _pinExplainer(WayfareTheme theme) {
    final mine = widget.existing!.isMine;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: WayfareColors.writtenBg,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.writtenBorder),
      ),
      child: Text(
        mine
            ? 'This is one of yours, so the planner leaves it alone. '
                'Regenerating asks before touching it.'
            : 'The planner wrote this. Once you change it, it becomes yours '
                'and regenerating will ask before touching it.',
        style: WayfareType.body(13, color: WayfareColors.writtenInkDeep),
      ),
    );
  }

  /// 2×2 including `Anytime`, each with its own time-of-day dot.
  Widget _slotGrid() {
    const slots = [
      TimeOfDay.morning,
      TimeOfDay.afternoon,
      TimeOfDay.evening,
      TimeOfDay.anytime,
    ];

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SlotButton(
                    slot: slots[row * 2 + col],
                    selected: _slot == slots[row * 2 + col],
                    onTap: () => setState(() => _slot = slots[row * 2 + col]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _moreFields(WayfareTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Description'),
        WayfareTextField(
          controller: _description,
          hint: 'Anything worth remembering',
          maxLines: 3,
        ),
        const SizedBox(height: 15),
        _label('How long'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in _durationChips)
              WayfareSelectChip(
                label: chip.label,
                selected: int.tryParse(_duration.text.trim()) == chip.minutes,
                onTap: () => setState(
                  () => _duration.text = chip.minutes.toString(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'or type it',
              style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: WayfareTextField(
                controller: _duration,
                hint: 'minutes',
                // Typing clears whichever chip was lit, so the two never
                // disagree about the same number.
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _label('Cost per person'),
        WayfareTextField(controller: _cost, hint: 'optional'),
        const SizedBox(height: 6),
        Text(
          'Left blank, the card reads free.',
          style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
        ),
        const SizedBox(height: 15),
        _OptionalSwitch(
          value: _optional,
          onChanged: (v) => setState(() => _optional = v),
        ),
        const SizedBox(height: 15),
        _label('If the weather turns'),
        WayfareTextField(controller: _weather, hint: 'optional'),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: WayfareColors.inkSecondary,
          ),
        ),
      );
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final TimeOfDay slot;
  final bool selected;
  final VoidCallback onTap;

  static String _label(TimeOfDay slot) => switch (slot) {
        TimeOfDay.morning => 'Morning',
        TimeOfDay.afternoon => 'Afternoon',
        TimeOfDay.evening => 'Evening',
        TimeOfDay.anytime => 'Anytime',
      };

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? WayfareColors.ink : WayfareColors.surfaceAlt,
        borderRadius: theme.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: theme.card,
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: theme.card,
              border: Border.all(
                color: selected ? WayfareColors.ink : WayfareColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: timeOfDayColor(slot),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _label(slot),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: selected
                        ? WayfareColors.surface
                        : WayfareColors.inkSecondary,
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

/// An optional clock time. Blank is the normal case, so clearing is one tap.
class _TimeField extends StatelessWidget {
  const _TimeField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Row(
      children: [
        Expanded(
          child: Material(
            color: WayfareColors.surfaceAlt,
            borderRadius: theme.card,
            child: InkWell(
              borderRadius: theme.card,
              onTap: () async {
                final picked = await pickWayfareTime(context, initial: value);
                if (picked != null) onChanged(picked);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: WayfareTouch.input),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: theme.card,
                  border: Border.all(color: WayfareColors.border),
                ),
                child: Text(
                  value ?? 'No set time',
                  style: TextStyle(
                    fontSize: 15,
                    color: value == null
                        ? WayfareColors.mutedLight
                        : WayfareColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: () => onChanged(null),
            tooltip: 'Clear the time',
            icon: const Icon(Icons.close, size: 18),
            color: WayfareColors.removeIcon,
          ),
      ],
    );
  }
}

class _OptionalSwitch extends StatelessWidget {
  const _OptionalSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional activity',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 3),
              Text(
                value
                    ? 'Shown with a dashed border — skip it freely'
                    : 'Part of the plan',
                style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
              ),
            ],
          ),
        ),
        Semantics(
          toggled: value,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: WayfareColors.surface,
            activeTrackColor: WayfareColors.accent,
          ),
        ),
      ],
    );
  }
}

/// Named, outline, no destructive fill — and it names the day it empties.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.day, required this.onRemove});

  final int day;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: theme.pill,
      child: InkWell(
        borderRadius: theme.pill,
        onTap: onRemove,
        child: Container(
          constraints: const BoxConstraints(minHeight: WayfareTouch.input),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: theme.pill,
            border: Border.all(color: WayfareColors.destructiveBorder),
          ),
          child: Text(
            'Remove this activity from day $day',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: WayfareColors.destructiveInk,
            ),
          ),
        ),
      ),
    );
  }
}
