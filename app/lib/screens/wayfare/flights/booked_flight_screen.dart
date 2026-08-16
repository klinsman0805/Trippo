import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_client.dart';
import '../../../api/trippo_api.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/flight.dart';
import '../../../models/trip.dart';
import '../formatting.dart';
import '../pushed_screen.dart';

/// "I've already booked" — the shortest path to a dated trip.
///
/// Someone with a booking is not shopping. They know the flight; they just
/// want the planner to know when they land. So this asks for the two things
/// off their confirmation email and nothing else, and never shows a price:
/// they have already paid one, and inventing a figure would put it in the
/// budget as though it were still to come.
class BookedFlightScreen extends StatefulWidget {
  const BookedFlightScreen({
    super.key,
    required this.api,
    required this.trip,
    required this.onConfirmed,
  });

  final TrippoApi api;
  final Trip trip;

  /// Fired once both legs are stored and the trip's dates have moved.
  final ValueChanged<DateEnvelope?> onConfirmed;

  @override
  State<BookedFlightScreen> createState() => _BookedFlightScreenState();
}

class _BookedFlightScreenState extends State<BookedFlightScreen> {
  final _outboundNumber = TextEditingController();
  final _returnNumber = TextEditingController();

  DateTime? _outboundDate;
  DateTime? _returnDate;

  FlightOffer? _outbound;
  FlightOffer? _return;

  /// Per-field, because "we can't find that flight" belongs next to the
  /// number that was mistyped, not in a banner at the top of the screen.
  String? _outboundError;
  String? _returnError;

  bool _looking = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _outboundNumber.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _outboundNumber.dispose();
    _returnNumber.dispose();
    super.dispose();
  }

  bool get _canLookUp =>
      _outboundNumber.text.trim().isNotEmpty && _outboundDate != null;

  bool get _hasReturnLeg =>
      _returnNumber.text.trim().isNotEmpty && _returnDate != null;

  @override
  Widget build(BuildContext context) {
    return WayfarePushedScreen(
      title: 'Your booked flight',
      subtitle: 'Sets the trip dates',
      backLabel: 'Trip',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _intro(context),
            const SizedBox(height: WayfareSpace.cardGap),
            _leg(
              context,
              eyebrow: 'Getting there',
              controller: _outboundNumber,
              date: _outboundDate,
              onPickDate: (d) => setState(() {
                _outboundDate = d;
                _outbound = null;
                _outboundError = null;
              }),
              error: _outboundError,
              found: _outbound,
            ),
            const SizedBox(height: WayfareSpace.cardGap),
            _leg(
              context,
              eyebrow: 'Coming back',
              optional: true,
              controller: _returnNumber,
              date: _returnDate,
              onPickDate: (d) => setState(() {
                _returnDate = d;
                _return = null;
                _returnError = null;
              }),
              error: _returnError,
              found: _return,
            ),
            const SizedBox(height: WayfareSpace.sectionGap),
            if (_saveError != null) ...[
              Text(
                _saveError!,
                style: const TextStyle(
                  fontSize: 13,
                  color: WayfareColors.overBudget,
                ),
              ),
              const SizedBox(height: 10),
            ],
            WayfarePrimaryButton(
              label: _buttonLabel(),
              onPressed: _canLookUp && !_looking && !_saving ? _submit : null,
              minHeight: WayfareTouch.sheetCta,
            ),
            const SizedBox(height: 10),
            Text(
              'Nothing is booked or changed with the airline. This only tells '
              'the planner when you land and when you leave.',
              textAlign: TextAlign.center,
              style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
            ),
          ],
        ),
      ),
    );
  }

  String _buttonLabel() {
    if (_looking) return 'Looking it up…';
    if (_saving) return 'Setting your dates…';
    if (_outbound != null) return 'Use these dates';
    return 'Find my flight';
  }

  Widget _intro(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WayfareColors.infoBg,
        borderRadius: theme.cardLg,
        border: Border.all(color: WayfareColors.infoBorder),
      ),
      child: Text(
        'Your flight number is on your confirmation email — two letters and up '
        'to four digits, like MH123. Add the return leg too if you have one.',
        style: WayfareType.body(13.5, color: WayfareColors.infoBody),
      ),
    );
  }

  Widget _leg(
    BuildContext context, {
    required String eyebrow,
    required TextEditingController controller,
    required DateTime? date,
    required ValueChanged<DateTime> onPickDate,
    required String? error,
    required FlightOffer? found,
    bool optional = false,
  }) {
    return WayfareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WayfareEyebrow(eyebrow, size: 10.5),
              if (optional) ...[
                const Spacer(),
                Text(
                  'optional',
                  style: WayfareType.body(
                    12,
                    color: WayfareColors.mutedLight,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: WayfareTextField(
                  controller: controller,
                  hint: 'MH123',
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    // Flight numbers are letters and digits only; blocking the
                    // rest at the keyboard beats rejecting it after a round
                    // trip to the server.
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _DateField(
                  date: date,
                  onPick: onPickDate,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: WayfareColors.overBudget,
              ),
            ),
          ],
          if (found != null) ...[
            const SizedBox(height: 12),
            _FoundFlight(offer: found),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // First press looks the flights up; the second commits. Splitting them
    // means the group sees the times they are about to be given before those
    // times become the trip.
    if (_outbound == null) {
      await _lookUp();
      return;
    }
    await _confirm();
  }

  Future<void> _lookUp() async {
    setState(() {
      _looking = true;
      _outboundError = null;
      _returnError = null;
      _saveError = null;
    });

    try {
      final outbound = await widget.api.lookupFlight(
        flightNumber: _outboundNumber.text.trim(),
        scheduledDate: _iso(_outboundDate!),
      );

      FlightOffer? back;
      if (_hasReturnLeg) {
        back = await widget.api.lookupFlight(
          flightNumber: _returnNumber.text.trim(),
          scheduledDate: _iso(_returnDate!),
          direction: 'return',
        );
      }

      setState(() {
        _outbound = outbound;
        _return = back;
        _outboundError = outbound == null ? _notFound(_outboundNumber, _outboundDate!) : null;
        _returnError = _hasReturnLeg && back == null
            ? _notFound(_returnNumber, _returnDate!)
            : null;
      });
    } on ApiException catch (e) {
      setState(() => _saveError = e.message);
    }

    if (mounted) setState(() => _looking = false);
  }

  String _notFound(TextEditingController controller, DateTime date) =>
      "We can't find ${controller.text.trim().toUpperCase()} on "
      '${formatLongDate(date)}. Check the number and the date — flights are '
      'listed under the airline that operates them, which is not always the '
      'one you booked with.';

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      var envelope = await widget.api.selectFlight(
        widget.trip.id,
        direction: 'outbound',
        offer: _outbound!,
      );
      if (_return != null) {
        envelope = await widget.api.selectFlight(
          widget.trip.id,
          direction: 'return',
          offer: _return!,
        );
      }
      if (mounted) widget.onConfirmed(envelope);
    } on ApiException catch (e) {
      setState(() {
        _saveError = e.message;
        _saving = false;
      });
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// What the lookup found, in the same plain register as the rest: times first,
/// route second, no price — because there isn't one to show.
class _FoundFlight extends StatelessWidget {
  const _FoundFlight({required this.offer});

  final FlightOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final segments = offer.itineraries.expand((i) => i.segments).toList();
    if (segments.isEmpty) return const SizedBox.shrink();

    final first = segments.first;
    final last = segments.last;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WayfareColors.successBgAlt,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.successBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${timeOf(first.departsAt)} → ${timeOf(last.arrivesAt)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WayfareColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${first.origin} → ${last.destination} · '
            '${weekdayAndDate(last.arrivesAt)}',
            style: const TextStyle(
              fontSize: 12.5,
              color: WayfareColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Already booked — no fare shown',
            style: WayfareType.body(12.5, color: WayfareColors.liveFareInk),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});

  final DateTime? date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Material(
      color: WayfareColors.surfaceAlt,
      borderRadius: theme.card,
      child: InkWell(
        borderRadius: theme.card,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            // A booking can be for a flight that has already departed — people
            // plan the rest of a trip mid-trip — so yesterday is allowed.
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
          );
          if (picked != null) onPick(picked);
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
            date == null ? 'Pick a date' : formatLongDate(date),
            style: TextStyle(
              fontSize: 15,
              color: date == null
                  ? WayfareColors.mutedLight
                  : WayfareColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
