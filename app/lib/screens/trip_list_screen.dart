import 'package:flutter/material.dart';

import '../api/trippo_api.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../models/trip.dart';
import '../state/trip_repository.dart';
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

  Future<void> _createTrip() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WayfareColors.surface,
        title: Text('New trip', style: WayfareType.display(24)),
        content: WayfareTextField(
          controller: controller,
          hint: 'e.g. Portugal, Slowly',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: WayfareColors.mutedLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Create',
              style: TextStyle(color: WayfareColors.accent),
            ),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;
    final trip = await _repo.create(title);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
            _FeatureNotice(repo: _repo),
            Expanded(child: _body()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: WayfarePrimaryButton(
                label: 'Start a new trip',
                onPressed: _createTrip,
              ),
            ),
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
                'Start one, add who\'s coming, and the planner takes it from there.',
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
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: onDelete,
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
      if (!repo.plannerAvailable) 'Planning is off — no ANTHROPIC_API_KEY set',
      if (!repo.mapsAvailable)
        'Maps and transit are off — no GOOGLE_MAPS_API_KEY set',
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
