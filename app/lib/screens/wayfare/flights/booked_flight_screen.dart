import 'package:flutter/cupertino.dart';
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
/// want the planner to know when they land. So the flow asks for the one thing
/// they can read off a confirmation email without thinking — the flight number
/// — and works out the rest from there.
///
/// Dates come *after* the number rather than beside it. Most people book for
/// today or tomorrow, and asking for a date up front makes them find a
/// calendar before they can start. And no price is ever shown: they have paid
/// one already, and we were not there.
class BookedFlightScreen extends StatefulWidget {
  const BookedFlightScreen({
    super.key,
    required this.api,
    required this.trip,
    required this.onConfirmed,
  });

  final TrippoApi api;
  final Trip trip;

  /// Fired once the legs are stored and the trip's dates have moved.
  final ValueChanged<DateEnvelope?> onConfirmed;

  @override
  State<BookedFlightScreen> createState() => _BookedFlightScreenState();
}

/// Which leg the date/time questions currently apply to.
enum _Leg { outbound, back }

class _BookedFlightScreenState extends State<BookedFlightScreen> {
  final _outboundNumber = TextEditingController();
  final _returnNumber = TextEditingController();

  /// The numbers as they were when "Find my flight" was last pressed.
  ///
  /// The date questions read these rather than the live fields: a heading that
  /// rewrites itself on every keystroke is noise, and half a flight number in
  /// a question reads as a bug.
  String? _confirmedOutbound;
  String? _confirmedReturn;

  DateTime? _outboundDate;
  DateTime? _returnDate;

  /// The departures found for the date currently being answered.
  List<FlightOffer> _options = const [];
  _Leg? _awaitingChoice;

  FlightOffer? _outbound;
  FlightOffer? _back;

  /// True once the traveller has said whether there is a return leg, so the
  /// prompt stops reappearing after they skip it.
  bool _returnSettled = false;

  String? _error;
  bool _looking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Only the CTA's enabled state depends on the text, so this is the one
    // thing that rebuilds as they type.
    _outboundNumber.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _outboundNumber.dispose();
    _returnNumber.dispose();
    super.dispose();
  }

  String get _typedOutbound => _outboundNumber.text.trim().toUpperCase();
  String get _typedReturn => _returnNumber.text.trim().toUpperCase();

  bool get _hasReturnNumber => (_confirmedReturn ?? '').isNotEmpty;

  /// The return can't leave before the outbound lands.
  DateTime get _earliestReturn => _outboundDate ?? _today;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

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
          children: _steps(context),
        ),
      ),
    );
  }

  List<Widget> _steps(BuildContext context) {
    final steps = <Widget>[
      _numbersCard(context),
      const SizedBox(height: WayfareSpace.cardGap),
    ];

    if (_error != null) {
      steps
        ..add(_errorPanel(context))
        ..add(const SizedBox(height: WayfareSpace.cardGap));
    }

    // --- outbound ---
    if (_outbound != null) {
      steps
        ..add(_chosenLeg(
          context,
          eyebrow: 'Getting there',
          offer: _outbound!,
          onChange: () => setState(() {
            _outbound = null;
            _options = const [];
            _awaitingChoice = null;
          }),
        ))
        ..add(const SizedBox(height: WayfareSpace.cardGap));
    } else if (_confirmedOutbound != null) {
      steps
        ..add(_dateStep(
          context,
          leg: _Leg.outbound,
          eyebrow: 'Getting there',
          question: 'When does $_confirmedOutbound take off?',
          selected: _outboundDate,
        ))
        ..add(const SizedBox(height: WayfareSpace.cardGap));

      if (_looking) {
        steps
          ..add(_lookingUp())
          ..add(const SizedBox(height: WayfareSpace.cardGap));
      } else if (_awaitingChoice == _Leg.outbound) {
        steps
          ..add(_timeStep(context, _Leg.outbound))
          ..add(const SizedBox(height: WayfareSpace.cardGap));
      }
    }

    // --- return ---
    if (_outbound != null) {
      if (_back != null) {
        steps
          ..add(_chosenLeg(
            context,
            eyebrow: 'Coming back',
            offer: _back!,
            onChange: () => setState(() {
              _back = null;
              _options = const [];
              _awaitingChoice = null;
            }),
          ))
          ..add(const SizedBox(height: WayfareSpace.cardGap));
      } else if (!_returnSettled && !_hasReturnNumber) {
        steps
          ..add(_returnPrompt(context))
          ..add(const SizedBox(height: WayfareSpace.cardGap));
      } else if (_hasReturnNumber) {
        steps
          ..add(_dateStep(
            context,
            leg: _Leg.back,
            eyebrow: 'Coming back',
            question: 'When does $_confirmedReturn take off?',
            selected: _returnDate,
          ))
          ..add(const SizedBox(height: WayfareSpace.cardGap));

        if (_looking) {
          steps
            ..add(_lookingUp())
            ..add(const SizedBox(height: WayfareSpace.cardGap));
        } else if (_awaitingChoice == _Leg.back) {
          steps
            ..add(_timeStep(context, _Leg.back))
            ..add(const SizedBox(height: WayfareSpace.cardGap));
        }
      }
    }

    // --- confirm ---
    if (_outbound != null && (_back != null || _returnSettled)) {
      steps
        ..add(const SizedBox(height: 2))
        ..add(WayfarePrimaryButton(
          label: _saving ? 'Setting your dates…' : 'Use these dates',
          onPressed: _saving ? null : _confirm,
          minHeight: WayfareTouch.sheetCta,
        ))
        ..add(const SizedBox(height: 10))
        ..add(Text(
          'Nothing is booked or changed with the airline. This only tells the '
          'planner when you land and when you leave.',
          textAlign: TextAlign.center,
          style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
        ));
    }

    return steps;
  }

  // --- step 1: the numbers ---

  Widget _numbersCard(BuildContext context) {
    return WayfareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WayfareEyebrow('Flight numbers', size: 10.5),
          const SizedBox(height: 8),
          Text(
            "It's on your confirmation email — two letters and up to four "
            'digits, like AK892. Dates come next.',
            style: WayfareType.body(13, color: WayfareColors.subhead),
          ),
          const SizedBox(height: 14),
          _numberField(
            label: 'Getting there',
            controller: _outboundNumber,
            enabled: _outbound == null,
          ),
          const SizedBox(height: 12),
          _numberField(
            label: 'Coming back',
            controller: _returnNumber,
            optional: true,
            enabled: _back == null,
          ),
          const SizedBox(height: 16),
          WayfarePrimaryButton(
            label: 'Find my flight',
            onPressed: _typedOutbound.isEmpty ? null : _findMyFlight,
          ),
        ],
      ),
    );
  }

  /// Start the lookup with whatever is in the fields right now.
  ///
  /// Pressing this again after changing a number redoes only the leg that
  /// actually changed — retyping the return should not throw away an outbound
  /// that was already confirmed.
  void _findMyFlight() {
    final outboundChanged = _typedOutbound != _confirmedOutbound;

    setState(() {
      _error = null;
      _options = const [];
      _awaitingChoice = null;

      if (outboundChanged) {
        _confirmedOutbound = _typedOutbound;
        _outboundDate = null;
        _outbound = null;
        _returnDate = null;
        _back = null;
        _returnSettled = false;
      }

      final typedReturn = _typedReturn;
      if (typedReturn != _confirmedReturn) {
        _confirmedReturn = typedReturn.isEmpty ? null : typedReturn;
        _returnDate = null;
        _back = null;
        // A return number typed after skipping means they changed their mind.
        if (typedReturn.isNotEmpty) _returnSettled = false;
      }
    });
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool optional = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            optional ? '$label · optional' : label,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: WayfareColors.inkSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: WayfareTextField(
                controller: controller,
                hint: 'AK892',
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                  LengthLimitingTextInputFormatter(7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- steps 3-6: the date ---

  Widget _dateStep(
    BuildContext context, {
    required _Leg leg,
    required String eyebrow,
    required String question,
    required DateTime? selected,
  }) {
    final selectedLabel =
        selected == null ? 'Choose a date' : formatLongDate(selected);

    return WayfareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WayfareEyebrow(eyebrow, size: 10.5),
          const SizedBox(height: 8),
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 13),
          // No "today" or "tomorrow" shortcuts: trips are planned weeks out,
          // so those would be the two dates nobody picks.
          WayfareSecondaryButton(
            label: selectedLabel,
            onPressed: () => _openDatePicker(context, leg),
            minHeight: WayfareTouch.input,
          ),
          if (leg == _Leg.back) ...[
            const SizedBox(height: 10),
            Text(
              'Anything before ${formatLongDate(_earliestReturn)} is closed off '
              '— that is when you get there.',
              style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
            ),
          ],
        ],
      ),
    );
  }

  /// The platform's own picker: the scrolling wheel on iOS, the Material
  /// calendar on Android. A custom one would be a worse version of both.
  Future<void> _openDatePicker(BuildContext context, _Leg leg) async {
    final theme = WayfareTheme.of(context);
    final earliest = leg == _Leg.back ? _earliestReturn : DateTime(2020);
    final initial = (leg == _Leg.back ? _returnDate : _outboundDate) ??
        (leg == _Leg.back ? _earliestReturn : _today);
    final last = DateTime(DateTime.now().year + 2, 12, 31);

    if (theme.isAndroid) {
      final picked = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(earliest) ? earliest : initial,
        firstDate: earliest,
        lastDate: last,
      );
      if (picked != null) _pickDate(leg, picked);
      return;
    }

    var draft = initial.isBefore(earliest) ? earliest : initial;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: WayfareColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.sheetRadius)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: WayfareColors.mutedLight),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: WayfareColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 240,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: draft,
                minimumDate: earliest,
                maximumDate: last,
                onDateTimeChanged: (d) => draft = DateTime(d.year, d.month, d.day),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed ?? false) _pickDate(leg, draft);
  }

  void _pickDate(_Leg leg, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    setState(() {
      if (leg == _Leg.outbound) {
        _outboundDate = day;
        _outbound = null;
        // A new outbound date can invalidate the return that follows it.
        if (_returnDate != null && _returnDate!.isBefore(day)) {
          _returnDate = null;
          _back = null;
        }
      } else {
        _returnDate = day;
        _back = null;
      }
      _options = const [];
      _awaitingChoice = null;
    });
    _lookUp(leg);
  }

  // --- steps 7-8: pick the departure ---

  Widget _timeStep(BuildContext context, _Leg leg) {
    final number = (leg == _Leg.outbound ? _outboundNumber : _returnNumber)
        .text
        .trim()
        .toUpperCase();

    return WayfareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WayfareEyebrow('Which departure', size: 10.5),
          const SizedBox(height: 8),
          Text(
            _options.length == 1
                ? 'This is the only $number that day. Tap to confirm it.'
                : '$number flies ${_options.length} times that day. Pick the '
                    'one you are on.',
            style: WayfareType.body(13.5, color: WayfareColors.subhead),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _DepartureRow(
              offer: _options[i],
              onTap: () => _chooseDeparture(leg, _options[i]),
            ),
          ],
        ],
      ),
    );
  }

  void _chooseDeparture(_Leg leg, FlightOffer offer) {
    setState(() {
      if (leg == _Leg.outbound) {
        _outbound = offer;
      } else {
        _back = offer;
        _returnSettled = true;
      }
      _options = const [];
      _awaitingChoice = null;
    });
  }

  // --- step 9: the return prompt ---

  Widget _returnPrompt(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WayfareColors.infoBg,
        borderRadius: theme.cardLg,
        border: Border.all(color: WayfareColors.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flying back?', style: WayfareType.display(20)),
          const SizedBox(height: 8),
          Text(
            'Add the return flight number above and we will set your last day '
            'the same way. Skip it if this is one way, or you have not booked '
            'the way home yet.',
            style: WayfareType.body(13.5, color: WayfareColors.infoBody),
          ),
          const SizedBox(height: 14),
          WayfareSecondaryButton(
            label: 'Skip for now',
            onPressed: () => setState(() => _returnSettled = true),
            minHeight: WayfareTouch.ios,
            fontSize: 13.5,
            foreground: WayfareColors.infoText,
          ),
        ],
      ),
    );
  }

  // --- shared pieces ---

  Widget _chosenLeg(
    BuildContext context, {
    required String eyebrow,
    required FlightOffer offer,
    required VoidCallback onChange,
  }) {
    final theme = WayfareTheme.of(context);
    final segments = offer.itineraries.expand((i) => i.segments).toList();
    final first = segments.first;
    final last = segments.last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WayfareColors.successBgAlt,
        borderRadius: theme.cardLg,
        border: Border.all(color: WayfareColors.successBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WayfareEyebrow(
                  eyebrow,
                  size: 10.5,
                  color: WayfareColors.liveFareInk,
                ),
                const SizedBox(height: 7),
                Text(
                  '${timeOf(first.departsAt)} → ${timeOf(last.arrivesAt)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${first.flightNumber} · ${first.origin} → '
                  '${last.destination} · ${weekdayAndDate(first.departsAt)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: WayfareColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onChange,
            child: const Text(
              'Change',
              style: TextStyle(fontSize: 13.5, color: WayfareColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lookingUp() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const WayfarePulsingDots(
              colors: WayfareColors.loadingDots,
              size: 8,
            ),
            const SizedBox(height: 12),
            Text(
              'Checking the schedule…',
              style: WayfareType.body(13, color: WayfareColors.mutedLight),
            ),
          ],
        ),
      );

  Widget _errorPanel(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: WayfareColors.overBg,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.overBorder),
      ),
      child: Text(
        _error!,
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: WayfareColors.overBudget,
        ),
      ),
    );
  }

  // --- network ---

  Future<void> _lookUp(_Leg leg) async {
    final controller =
        leg == _Leg.outbound ? _outboundNumber : _returnNumber;
    final date = leg == _Leg.outbound ? _outboundDate : _returnDate;
    if (date == null) return;

    setState(() {
      _looking = true;
      _error = null;
    });

    try {
      final offers = await widget.api.lookupFlights(
        flightNumber: controller.text.trim(),
        scheduledDate: _iso(date),
        direction: leg == _Leg.outbound ? 'outbound' : 'return',
      );

      setState(() {
        _options = offers;
        _awaitingChoice = offers.isEmpty ? null : leg;
        _error = offers.isEmpty
            ? "We can't find ${controller.text.trim().toUpperCase()} on "
                '${formatLongDate(date)}. Check the number and the date — '
                'flights are listed under the airline that operates them, '
                'which is not always the one you booked through.'
            : null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }

    if (mounted) setState(() => _looking = false);
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var envelope = await widget.api.selectFlight(
        widget.trip.id,
        direction: 'outbound',
        offer: _outbound!,
      );
      if (_back != null) {
        envelope = await widget.api.selectFlight(
          widget.trip.id,
          direction: 'return',
          offer: _back!,
        );
      }
      if (mounted) widget.onConfirmed(envelope);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// One departure to choose between. Times are local to their own airport —
/// a 16:55 from KUL and an 18:45 from Bangkok both read as the boarding pass
/// does, because converting them would make the screen disagree with it.
class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.offer, required this.onTap});

  final FlightOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final segments = offer.itineraries.expand((i) => i.segments).toList();
    if (segments.isEmpty) return const SizedBox.shrink();

    final first = segments.first;
    final last = segments.last;
    final overnight =
        last.arrivesAt.substring(0, 10) != first.departsAt.substring(0, 10);

    return Material(
      color: WayfareColors.surfaceAlt,
      borderRadius: theme.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.card,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: theme.card,
            border: Border.all(color: WayfareColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${timeOf(first.departsAt)} → ${timeOf(last.arrivesAt)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // Landing the next day changes which day the trip
                        // starts, so it is stated rather than left to be
                        // inferred from two times that read as going backwards.
                        if (overnight) ...[
                          const SizedBox(width: 6),
                          Text(
                            '+1 day',
                            style: WayfareType.body(
                              12,
                              color: WayfareColors.mutedLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${first.origin} → ${last.destination} · '
                      '${formatDuration(offer.itineraries.first.durationMinutes)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WayfareColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: WayfareColors.removeIcon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
