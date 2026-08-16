import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/flight.dart';
import '../../../state/flights_controller.dart';
import '../formatting.dart';

/// The flight search query: route and dates, then who and how.
class FlightSearchForm extends StatefulWidget {
  const FlightSearchForm({super.key, required this.controller});

  final FlightsController controller;

  @override
  State<FlightSearchForm> createState() => _FlightSearchFormState();
}

class _FlightSearchFormState extends State<FlightSearchForm> {
  final _fromField = TextEditingController();
  final _toField = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  /// Which field the type-ahead list belongs to. Only one can be open.
  _Field? _active;

  FlightsController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (c.from != null) _fromField.text = _label(c.from!);
    if (c.to != null) _toField.text = _label(c.to!);
  }

  @override
  void dispose() {
    _fromField.dispose();
    _toField.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  static String _label(Airport a) => '${a.iata} · ${a.name}';

  void _onQueryChanged(_Field field, String value) {
    setState(() => _active = field);
    c.searchAirports(value);
  }

  void _pick(Airport airport) {
    if (_active == _Field.from) {
      c.setFrom(airport);
      _fromField.text = _label(airport);
      _toFocus.requestFocus();
    } else {
      c.setTo(airport);
      _toField.text = _label(airport);
      _toFocus.unfocus();
    }
    setState(() => _active = null);
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final now = DateTime.now();
    final firstAllowed = isReturn && c.departureDate != null
        ? DateTime.parse(c.departureDate!)
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: firstAllowed,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final iso = picked.toIso8601String().substring(0, 10);
    if (isReturn) {
      c.setReturnDate(iso);
    } else {
      c.setDepartureDate(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _routeCard(),
        const SizedBox(height: 12),
        _whoCard(),
        const SizedBox(height: 16),
        if (c.error != null) ...[
          Text(
            c.error!,
            style: const TextStyle(
              fontSize: 13,
              color: WayfareColors.destructiveInk,
            ),
          ),
          const SizedBox(height: 12),
        ],
        WayfarePrimaryButton(
          label: 'Search flights',
          onPressed: c.canSearch ? c.search : null,
          minHeight: WayfareTouch.sheetCta,
          fontSize: 15.5,
        ),
        const SizedBox(height: 12),
        // The most important sentence on the screen: this step is about dates,
        // and nothing here books anything.
        const Text(
          'Dates come from the flights you pick. Nothing is booked here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
        ),
      ],
    );
  }

  Widget _routeCard() {
    return WayfareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('From'),
          _AirportField(
            controller: _fromField,
            focusNode: _fromFocus,
            hint: 'City or airport',
            onChanged: (v) => _onQueryChanged(_Field.from, v),
          ),
          if (_active == _Field.from) _suggestions(),
          const SizedBox(height: 14),
          _fieldLabel('To'),
          _AirportField(
            controller: _toField,
            focusNode: _toFocus,
            hint: 'City or airport',
            onChanged: (v) => _onQueryChanged(_Field.to, v),
          ),
          if (_active == _Field.to) _suggestions(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel('Departing'),
                    _DateField(
                      value: c.departureDate,
                      onTap: () => _pickDate(isReturn: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The label carries the one-way state rather than the
                    // field being silently dead.
                    _fieldLabel(c.oneWay ? 'Returning (off)' : 'Returning'),
                    _DateField(
                      value: c.oneWay ? null : c.returnDate,
                      enabled: !c.oneWay,
                      onTap: () => _pickDate(isReturn: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              WayfareSelectChip(
                label: 'Return trip',
                selected: !c.oneWay,
                onTap: () => c.setOneWay(false),
                minHeight: 40,
              ),
              const SizedBox(width: 8),
              WayfareSelectChip(
                label: 'One way',
                selected: c.oneWay,
                onTap: () => c.setOneWay(true),
                minHeight: 40,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestions() {
    final theme = WayfareTheme.of(context);
    if (c.suggestionsLoading && c.suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Searching…',
          style: TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
        ),
      );
    }
    if (c.suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.borderSoft),
      ),
      child: Column(
        children: [
          for (var i = 0; i < c.suggestions.length; i++)
            _SuggestionRow(
              airport: c.suggestions[i],
              showDivider: i > 0,
              onTap: () => _pick(c.suggestions[i]),
            ),
        ],
      ),
    );
  }

  Widget _whoCard() {
    return WayfareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Travellers',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.trip.members.isEmpty
                          ? 'Nobody added yet'
                          : c.trip.members.map((m) => m.name.split(' ').first).join(', '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WayfareColors.mutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              _StepperButton(
                icon: Icons.remove,
                onTap: c.seats > 1 ? () => c.setSeats(c.seats - 1) : null,
              ),
              SizedBox(
                width: 66,
                child: Text(
                  '${c.seats} ${c.seats == 1 ? 'seat' : 'seats'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                onTap: c.seats < 8 ? () => c.setSeats(c.seats + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _fieldLabel('Cabin'),
          Row(
            children: [
              for (final (value, label) in const [
                ('ECONOMY', 'Economy'),
                ('PREMIUM_ECONOMY', 'Premium'),
                ('BUSINESS', 'Business'),
              ]) ...[
                if (value != 'ECONOMY') const SizedBox(width: 8),
                Expanded(
                  child: _CabinButton(
                    label: label,
                    selected: c.cabin == value,
                    onTap: () => c.setCabin(value),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Non-stop only',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    // Live sub-line: says what the toggle costs either way.
                    // The route only appears once both ends are known, so the
                    // sentence never reads with a gap in it.
                    Text(
                      c.nonStop
                          ? (c.from != null && c.to != null
                              ? 'Only direct ${c.from!.iata}–${c.to!.iata} flights'
                              : 'Direct flights only, where they exist')
                          : 'One-stop fares are usually cheaper',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WayfareColors.mutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NonStopSwitch(
                value: c.nonStop,
                onChanged: c.setNonStop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
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

enum _Field { from, to }

/// Focused fields take a 2px accent border and the lighter surface, so the
/// active one is unmistakable while typing.
class _AirportField extends StatelessWidget {
  const _AirportField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16, color: WayfareColors.ink),
      cursorColor: WayfareColors.ink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: WayfareColors.mutedLight),
        filled: true,
        fillColor: focusNode.hasFocus
            ? WayfareColors.surface
            : WayfareColors.surfaceAlt,
        constraints: const BoxConstraints(minHeight: WayfareTouch.input),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: theme.card,
          borderSide: const BorderSide(color: WayfareColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: theme.card,
          borderSide: const BorderSide(color: WayfareColors.accent, width: 2),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.airport,
    required this.showDivider,
    required this.onTap,
  });

  final Airport airport;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(top: BorderSide(color: WayfareColors.skeletonLight))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                airport.iata,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.52,
                  color: WayfareColors.accent,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    airport.city ?? airport.name,
                    style: const TextStyle(fontSize: 14.5),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    airport.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: WayfareColors.mutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: theme.card,
        child: Container(
          constraints: const BoxConstraints(minHeight: WayfareTouch.input),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: WayfareColors.surfaceAlt,
            borderRadius: theme.card,
            border: Border.all(color: WayfareColors.border),
          ),
          child: Text(
            value == null ? 'Pick a date' : formatShortDate(value),
            style: TextStyle(
              fontSize: 16,
              color: value == null ? WayfareColors.mutedLight : WayfareColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.pill,
        child: Container(
          width: WayfareTouch.ios,
          height: WayfareTouch.ios,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: WayfareColors.surfaceAlt,
            borderRadius: theme.pill,
            border: Border.all(color: WayfareColors.border),
          ),
          child: Icon(icon, size: 18, color: WayfareColors.ink),
        ),
      ),
    );
  }
}

class _CabinButton extends StatelessWidget {
  const _CabinButton({
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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

/// Custom track on iOS to match the spec's 52×32 / terracotta; Android gets
/// the platform Switch, per the handoff's rule about native chrome.
class _NonStopSwitch extends StatelessWidget {
  const _NonStopSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (WayfareTheme.of(context).isAndroid) {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: WayfareColors.accent,
      );
    }

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? WayfareColors.accent : WayfareColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
