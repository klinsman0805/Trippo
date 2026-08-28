import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/services.dart';

import '../../../api/api_client.dart';
import '../../../api/trippo_api.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../formatting.dart';
import '../platform_pickers.dart';

/// The flight, as the traveller reads it off their booking.
///
/// The escape hatch for a schedule feed with gaps. Ours is demonstrably
/// incomplete — it carries AK893 on the 27th and 30th but not the 29th, which
/// other sources have — and someone holding a boarding pass is simply right
/// where we are wrong. Nothing downstream can tell the difference: the result
/// is shaped exactly like a looked-up flight.
class ManualFlightSheet extends StatefulWidget {
  const ManualFlightSheet({
    super.key,
    required this.api,
    required this.flightNumber,
    required this.date,
    required this.direction,
    required this.onCancel,
  });

  final TrippoApi api;
  final String flightNumber;
  final DateTime date;
  final String direction;
  final VoidCallback onCancel;

  @override
  State<ManualFlightSheet> createState() => _ManualFlightSheetState();
}

class _ManualFlightSheetState extends State<ManualFlightSheet> {
  final _from = TextEditingController();
  final _to = TextEditingController();

  /// `HH:MM`, local to their own airport.
  String? _departs;
  String? _arrives;

  /// Landing after midnight is common on evening flights, and it changes which
  /// day the trip starts — so it is asked rather than inferred.
  bool _arrivesNextDay = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _from.addListener(() => setState(() {}));
    _to.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _from.text.trim().length == 3 &&
      _to.text.trim().length == 3 &&
      _departs != null &&
      _arrives != null;

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
          // The grabber sits outside the scroll view: inside it, a downward
          // drag scrolls the content instead of dismissing the sheet, which
          // is the gesture everyone reaches for to close one.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WayfareSheetGrabber(),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 46 + viewInsets),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              widget.flightNumber,
                              style: WayfareType.display(24),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onCancel,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                color: WayfareColors.mutedLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        formatLongDate(widget.date),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WayfareColors.mutedLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Copy these off your booking. Times are local to each '
                        'airport — exactly as they print on the ticket, with no '
                        'converting.',
                        style: WayfareType.body(
                          13.5,
                          color: WayfareColors.subhead,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _airportField('From', _from)),
                          const SizedBox(width: 10),
                          Expanded(child: _airportField('To', _to)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _timeField(
                              'Departs',
                              _departs,
                              (t) => setState(() => _departs = t),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _timeField(
                              'Arrives',
                              _arrives,
                              (t) => setState(() => _arrives = t),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _nextDayRow(),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: WayfareColors.overBudget,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      WayfarePrimaryButton(
                        label: _saving ? 'Saving…' : 'Use this flight',
                        onPressed: _canSave && !_saving ? _save : null,
                        minHeight: WayfareTouch.sheetCta,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _airportField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label),
        WayfareTextField(
          controller: controller,
          hint: 'KUL',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
            LengthLimitingTextInputFormatter(3),
          ],
        ),
      ],
    );
  }

  Widget _timeField(String label, String? value, ValueChanged<String> onPick) {
    final theme = WayfareTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label),
        Material(
          color: WayfareColors.surfaceAlt,
          borderRadius: theme.card,
          child: InkWell(
            borderRadius: theme.card,
            onTap: () async {
              final picked = await pickWayfareTime(context, initial: value);
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
                value == null ? '--:--' : formatClock(value),
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
      ],
    );
  }

  Widget _nextDayRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lands the next day',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 3),
              Text(
                'Common on late departures, and it moves which day your trip '
                'starts.',
                style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
              ),
            ],
          ),
        ),
        Switch(
          value: _arrivesNextDay,
          onChanged: (v) => setState(() => _arrivesNextDay = v),
          activeThumbColor: WayfareColors.surface,
          activeTrackColor: WayfareColors.accent,
        ),
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

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final arrivalDate = _arrivesNextDay
        ? widget.date.add(const Duration(days: 1))
        : widget.date;

    try {
      final offer = await widget.api.manualFlight(
        flightNumber: widget.flightNumber,
        origin: _from.text.trim().toUpperCase(),
        destination: _to.text.trim().toUpperCase(),
        departsAt: '${_isoDate(widget.date)}T$_departs',
        arrivesAt: '${_isoDate(arrivalDate)}T$_arrives',
        direction: widget.direction,
      );
      if (mounted) Navigator.of(context).pop(offer);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }
}
