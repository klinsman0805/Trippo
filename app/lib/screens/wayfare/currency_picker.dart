import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/services.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import 'formatting.dart';

/// Picking the currency every figure in the trip is denominated in.
///
/// A shortlist of the currencies the app can print a symbol for, plus a field
/// for anything else — the list is a shortcut, not a restriction, and a trip
/// to somewhere outside it should not be unplannable.
class CurrencyPicker extends StatefulWidget {
  const CurrencyPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  late final TextEditingController _other = TextEditingController(
    text: wayfareCurrencies.contains(widget.value) ? '' : widget.value,
  );

  bool get _isOther => !wayfareCurrencies.contains(widget.value);

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final code in wayfareCurrencies)
              _Chip(
                label: '${currencySymbol(code)} $code',
                selected: widget.value == code,
                radius: BorderRadius.circular(theme.chipRadius),
                onTap: () {
                  _other.clear();
                  widget.onChanged(code);
                },
              ),
            _Chip(
              label: 'Other',
              selected: _isOther,
              radius: BorderRadius.circular(theme.chipRadius),
              onTap: () => widget.onChanged(''),
            ),
          ],
        ),
        if (_isOther || widget.value.isEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _other,
              autofocus: true,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                TextInputFormatter.withFunction(
                  (_, next) => next.copyWith(text: next.text.toUpperCase()),
                ),
              ],
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'e.g. VND',
                isDense: true,
                filled: true,
                fillColor: WayfareColors.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: theme.card,
                  borderSide: const BorderSide(color: WayfareColors.border),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.radius,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? WayfareColors.ink : WayfareColors.surfaceAlt,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? WayfareColors.ink : WayfareColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? WayfareColors.generatingInk
                    : WayfareColors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
