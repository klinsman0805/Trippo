import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/trip.dart';
import 'formatting.dart';

/// The traveller sheet — the same form whether you are adding someone or
/// editing them.
///
/// One component rather than two, because the fields are identical and a
/// separate edit form would drift from the add form the first time either
/// changed. Editing adds three things on top: who this is, what changing them
/// costs, and a way out of the trip.
class TravellerSheet extends StatefulWidget {
  const TravellerSheet({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.existing,
    this.onRemove,
    this.optionalForMember = const [],
    this.avatarColor,
  });

  /// The member being edited. Null adds a new one.
  final Member? existing;

  /// Member colours are assigned by position in the group, which this sheet
  /// cannot know. The caller passes it so the avatar here matches the one on
  /// the Group tab rather than picking a second colour for the same person.
  final Color? avatarColor;

  final ValueChanged<Member> onSave;
  final VoidCallback onCancel;

  /// Remove this traveller from the trip. Only offered when editing.
  final VoidCallback? onRemove;

  /// Blocks currently marked optional *for this person* — the concrete thing
  /// that changes if their pace or access needs change. Named specifically
  /// because "conflicts will be re-checked" tells the group nothing about what
  /// is actually at stake.
  final List<({int day, String activity})> optionalForMember;

  /// The interest vocabulary offered as chips. Free text is not accepted here
  /// by design — a fixed set keeps member interests comparable to each other,
  /// which is what the planner reconciles.
  static const interests = [
    'Food markets',
    'Museums',
    'Live music',
    'Surfing',
    'Hiking',
    'Wine',
    'Architecture',
    'Slow mornings',
    'Photography',
  ];

  @override
  State<TravellerSheet> createState() => _TravellerSheetState();
}

class _TravellerSheetState extends State<TravellerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _diet;
  late final TextEditingController _access;

  late final Set<String> _selectedInterests;
  late Pace _pace;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _name = TextEditingController(text: existing?.name ?? '');
    _diet = TextEditingController(
      text: existing?.dietaryRestrictions.join(', ') ?? '',
    );
    _access = TextEditingController(
      text: existing?.accessibilityNeeds.join(', ') ?? '',
    );
    // Interests the planner doesn't offer as chips are kept rather than
    // dropped — editing someone's name should not silently delete a
    // preference that came in from somewhere else.
    _selectedInterests = {...?existing?.interests};
    _pace = existing?.pace ?? Pace.moderate;

    // The Save button enables on the first character, so rebuild as they type.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _diet.dispose();
    _access.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    widget.onSave(
      Member(
        id: widget.existing?.id ?? '', // assigned by the server when adding
        name: _name.text.trim(),
        departureCity: widget.existing?.departureCity,
        interests: _selectedInterests.toList(),
        pace: _pace,
        budgetSensitivity: widget.existing?.budgetSensitivity,
        dietaryRestrictions: _splitList(_diet.text),
        accessibilityNeeds: _splitList(_access.text),
        // Not editable in this sheet; carried through so a save doesn't
        // silently clear what the planner was told elsewhere.
        dealBreakers: widget.existing?.dealBreakers ?? const [],
        wants: widget.existing?.wants ?? const [],
        avoids: widget.existing?.avoids ?? const [],
        createdAt: widget.existing?.createdAt,
      ),
    );
  }

  /// Comma-separated free text → a list, dropping empties.
  static List<String> _splitList(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: WayfareColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.sheetRadius),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                offset: Offset(0, -12),
                blurRadius: 40,
              ),
            ],
          ),
          child: SingleChildScrollView(
            // Lift the sheet above the keyboard rather than letting it cover
            // the Save button.
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
                if (_isEditing) _identityHeader() else _addHeader(),
                const SizedBox(height: 16),
                if (_isEditing) ...[
                  _knockOnPanel(theme),
                  const SizedBox(height: 15),
                ],
                _label('Name'),
                WayfareTextField(
                  controller: _name,
                  hint: 'e.g. Ana Silva',
                  // Editing opens on a filled field; stealing focus would put
                  // the keyboard over the form for no reason.
                  autofocus: !_isEditing,
                ),
                const SizedBox(height: 15),
                _label('Interests'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final interest in TravellerSheet.interests)
                      WayfareSelectChip(
                        label: interest,
                        selected: _selectedInterests.contains(interest),
                        onTap: () => setState(() {
                          if (!_selectedInterests.remove(interest)) {
                            _selectedInterests.add(interest);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 15),
                _label('Pace'),
                Row(
                  children: [
                    for (final pace in Pace.values) ...[
                      if (pace != Pace.values.first) const SizedBox(width: 8),
                      Expanded(
                        child: _PaceButton(
                          label: _paceLabel(pace),
                          selected: _pace == pace,
                          onTap: () => setState(() => _pace = pace),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 15),
                _label('Dietary needs'),
                WayfareTextField(controller: _diet, hint: 'optional'),
                const SizedBox(height: 15),
                _label('Accessibility needs'),
                WayfareTextField(controller: _access, hint: 'optional'),
                const SizedBox(height: 15),
                WayfarePrimaryButton(
                  label: _isEditing ? 'Save changes' : 'Save traveller',
                  onPressed: _canSave ? _save : null,
                  minHeight: WayfareTouch.sheetCta,
                  fontSize: 15.5,
                ),
                if (_isEditing && widget.onRemove != null) ...[
                  const SizedBox(height: 10),
                  _RemoveButton(
                    name: widget.existing!.name,
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
          Text('Add a traveller', style: WayfareType.display(24)),
          const Spacer(),
          _cancelButton(),
        ],
      );

  /// Who you are editing, and since when. The provenance line answers "is this
  /// the Ruth I added, or someone else's Ruth" before any field is touched.
  Widget _identityHeader() {
    final member = widget.existing!;
    final added = formatLongDate(member.createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WayfareAvatar(
          initials: initialsOf(member.name),
          color: widget.avatarColor ?? WayfareColors.memberColor(0),
          size: 38,
          ringWidth: 0,
          fontSize: 13,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name, style: WayfareType.display(22)),
              if (added.isNotEmpty)
                Text(
                  'Added $added',
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

  /// What an edit sets off. Concrete where it can be, honest where it can't.
  Widget _knockOnPanel(WayfareTheme theme) {
    final name = widget.existing!.name.split(' ').first;
    final optional = widget.optionalForMember;

    final detail = switch (optional.length) {
      0 => 'Nothing in the plan is currently marked optional for $name.',
      1 => "Day ${optional.first.day}'s ${optional.first.activity.toLowerCase()} "
          'is the only thing currently marked optional for $name.',
      _ => '${optional.length} activities are currently marked optional for '
          '$name, starting with day ${optional.first.day}.',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: WayfareColors.infoBg,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.infoBorder),
      ),
      child: Text(
        'Changing pace or access needs re-checks the conflicts. $detail',
        style: WayfareType.body(13, color: WayfareColors.infoBody),
      ),
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

  static String _paceLabel(Pace pace) => switch (pace) {
        Pace.packed => 'Packed',
        Pace.moderate => 'Moderate',
        Pace.relaxed => 'Relaxed',
      };
}

/// Named, never "Delete", and never a destructive fill — the design is
/// specific about this. It is still the only irreversible thing in the sheet,
/// so it confirms first.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final first = name.split(' ').first;

    return Material(
      color: Colors.transparent,
      borderRadius: theme.pill,
      child: InkWell(
        borderRadius: theme.pill,
        onTap: () => _confirm(context, first),
        child: Container(
          constraints: const BoxConstraints(minHeight: WayfareTouch.input),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: theme.pill,
            border: Border.all(color: WayfareColors.destructiveBorder),
          ),
          child: Text(
            'Remove $first from the trip',
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

  Future<void> _confirm(BuildContext context, String first) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove $first?',
      body: 'Their preferences go with them, and the planner will have one '
          'less person to balance. The itinerary stays until you regenerate it.',
      confirmLabel: 'Remove',
      cancelLabel: 'Keep them',
    );

    if (confirmed) onRemove();
  }
}

class _PaceButton extends StatelessWidget {
  const _PaceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Material(
      color: selected ? WayfareColors.ink : WayfareColors.surfaceAlt,
      borderRadius: theme.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.card,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: theme.card,
            border: Border.all(
              color: selected ? WayfareColors.ink : WayfareColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: selected ? WayfareColors.surface : WayfareColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
