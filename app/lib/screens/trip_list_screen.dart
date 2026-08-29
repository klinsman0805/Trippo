import 'package:flutter/material.dart';

import '../api/trippo_api.dart';
import '../design/features.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../models/trip.dart';
import '../state/trip_repository.dart';
import 'wayfare/currency_picker.dart';
import 'wayfare/formatting.dart';

/// Trip picker, shown before the four-tab shell.
///
/// The handoff covers a single trip and says nothing about choosing one, so
/// this fills a gap rather than contradicting the design — styled with the
/// same tokens so it doesn't read as a different app.
class TripListScreen extends StatefulWidget {
  const TripListScreen({
    super.key,
    required this.api,
    required this.onOpenTrip,
  });

  final TrippoApi api;
  final void Function(BuildContext context, String tripId) onOpenTrip;

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  late final TripListRepository _repo = TripListRepository(widget.api);

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChanged);
    _repo.load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChanged);
    _repo.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// The new-trip dialog asks where, not what to call it.
  ///
  /// It used to take a title only, and a title is not a destination — so every
  /// trip was created with none, `canGenerate` was false, and the planner
  /// could not be reached at all. The place you are going is the one thing the
  /// planner cannot work without, so it is the one thing this asks for.
  Future<void> _createTrip() async {
    final answer = await showDialog<({String destination, String currency})>(
      context: context,
      builder: (ctx) => const _NewTripDialog(),
    );

    if (answer == null || answer.destination.isEmpty) return;
    final trip = await _repo.create(
      answer.destination,
      destinations: [answer.destination],
      currency: answer.currency,
    );
    if (mounted) widget.onOpenTrip(context, trip.id);
  }

  @override
  Widget build(BuildContext context) {
    // The theme comes from the app root rather than being provided here: a
    // screen-level copy would not reach the dialogs this screen opens, and it
    // ignored the app's platform override.
    return Scaffold(
      backgroundColor: WayfareColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WayfareEyebrow(
                          'Wayfare',
                          color: WayfareColors.accent,
                          size: 13,
                        ),
                        const SizedBox(height: 2),
                        Text('Your trips', style: WayfareType.display(32)),
                      ],
                    ),
                  ),
                  // Matches the Trip tab's own header action, so adding is in
                  // the same place whichever screen you are on — and it stops
                  // a full-width button sitting under an empty list.
                  Semantics(
                    button: true,
                    label: 'Start a new trip',
                    child: Material(
                      color: WayfareColors.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _createTrip,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: WayfareTouch.input,
                          height: WayfareTouch.input,
                          child: Icon(
                            Icons.add,
                            size: 22,
                            color: WayfareColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _FeatureNotice(repo: _repo),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_repo.trips) {
      Idle() || Loading() => const Center(
        child: CircularProgressIndicator(color: WayfareColors.accent),
      ),
      Failed(:final error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Can\'t reach the server', style: WayfareType.display(24)),
              const SizedBox(height: 9),
              Text(
                error.message,
                textAlign: TextAlign.center,
                style: WayfareType.body(13.5, color: WayfareColors.subhead),
              ),
              const SizedBox(height: 18),
              WayfarePrimaryButton(label: 'Try again', onPressed: _repo.load),
            ],
          ),
        ),
      ),
      Loaded(:final value) when value.isEmpty => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No trips yet', style: WayfareType.display(24)),
              const SizedBox(height: 9),
              Text(
                'Tap + to start one. Say where you are going, and the planner '
                'takes it from there.',
                textAlign: TextAlign.center,
                style: WayfareType.body(13.5, color: WayfareColors.subhead),
              ),
            ],
          ),
        ),
      ),
      Loaded(:final value) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: value.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: WayfareSpace.cardGap),
        itemBuilder: (context, i) => _TripTile(
          trip: value[i],
          onOpen: () => widget.onOpenTrip(context, value[i].id),
          onDelete: () => _repo.delete(value[i].id),
        ),
      ),
    };
  }
}

/// Where are you going, and in what money.
///
/// Two questions, because both are things the app cannot work out for itself
/// and cannot sensibly default: a destination is what the planner needs to run
/// at all, and a currency silently defaulting to USD priced a Kuala Lumpur
/// trip in dollars.
class _NewTripDialog extends StatefulWidget {
  const _NewTripDialog();

  @override
  State<_NewTripDialog> createState() => _NewTripDialogState();
}

class _NewTripDialogState extends State<_NewTripDialog> {
  final _controller = TextEditingController();

  /// Seeded from the device's own region, which is right more often than any
  /// fixed default and wrong in a way the user can see and change.
  String _currency = localCurrency();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();
  bool get _canSubmit => _value.isNotEmpty && _currency.length == 3;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.pop(context, (destination: _value, currency: _currency));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: WayfareColors.surface,
      title: Text('Where are you going?', style: WayfareType.display(24)),
      // The currency chips need the room, and a dialog will not scroll on its
      // own — on a short screen this would otherwise overflow.
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WayfareTextField(
            controller: _controller,
            hint: 'e.g. Bangkok',
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'The trip takes this as its name. You can rename it later — the '
            'planner needs somewhere to go before it can plan anything.',
            style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
          ),
          const SizedBox(height: 18),
          Text(
            'Money',
            style: WayfareType.eyebrow(11.5, color: WayfareColors.muted),
          ),
          const SizedBox(height: 8),
          CurrencyPicker(
            value: _currency,
            onChanged: (v) => setState(() => _currency = v),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: WayfareColors.mutedLight),
          ),
        ),
        TextButton(
          // Dead until there is a destination, rather than creating a trip
          // that cannot be planned.
          onPressed: _canSubmit ? _submit : null,
          child: Text(
            'Create',
            style: TextStyle(
              color: _canSubmit
                  ? WayfareColors.accent
                  : WayfareColors.mutedLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.trip,
    required this.onOpen,
    required this.onDelete,
  });

  final Trip trip;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final subtitle = destinationsSubtitle(
      trip.destinations,
      trip.startDate,
      trip.endDate,
    );

    return Material(
      color: WayfareColors.surface,
      borderRadius: theme.cardLg,
      child: InkWell(
        onTap: onOpen,
        borderRadius: theme.cardLg,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: theme.cardLg,
            border: Border.all(color: WayfareColors.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: WayfareColors.muted,
                        ),
                      ),
                    ],
                    if (WayfareFeatures.groups) ...[
                      const SizedBox(height: 4),
                      Text(
                        trip.memberCount == 0
                            ? 'No travellers yet'
                            : '${trip.memberCount} '
                                  '${trip.memberCount == 1 ? 'traveller' : 'travellers'}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WayfareColors.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: () => _confirmDelete(context),
                  tooltip: 'Delete ${trip.title}',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: WayfareColors.removeIcon,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deleting a trip cascades on the server — members, imported sources and
  /// their places, flight selections and every plan revision go with it. That
  /// is far more than the one row the icon sits next to, so the dialog says so
  /// rather than asking a bare "are you sure?".
  Future<void> _confirmDelete(BuildContext context) async {
    final losses = [
      if (WayfareFeatures.groups && trip.memberCount > 0)
        '${trip.memberCount} '
            "${trip.memberCount == 1 ? "traveller's" : "travellers'"} "
            'preferences',
      'every plan it has produced',
      'anything imported into it',
    ];

    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${trip.title}?',
      body:
          'This takes ${_readableList(losses)} with it, and cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
    );

    if (confirmed) onDelete();
  }

  static String _readableList(List<String> items) {
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
}

/// Names any integration the server has no key for, so a disabled feature
/// reads as configuration rather than breakage.
class _FeatureNotice extends StatelessWidget {
  const _FeatureNotice({required this.repo});

  final TripListRepository repo;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final warnings = <String>[
      // Name the key the server actually reads. This said ANTHROPIC_API_KEY
      // long after the planner moved to Gemini, which would send anyone
      // troubleshooting to a variable that does nothing.
      if (!repo.plannerAvailable) 'Planning is off — no GEMINI_API_KEY set',
      if (!repo.mapsAvailable)
        'Maps and transit are off — MAPS_PROVIDER is google with no key set',
      if (repo.flightsAreEstimatesOnly) 'Flight prices are mock estimates',
    ];
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WayfareColors.warningBg,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings)
            Text(
              warning,
              style: const TextStyle(
                fontSize: 12.5,
                color: WayfareColors.warningText,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
