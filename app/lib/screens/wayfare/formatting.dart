import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../models/plan.dart' as plan_models;

/// Currency symbols for the currencies the app is likely to see. Anything else
/// falls back to the ISO code, which is honest rather than wrong.
const _symbols = <String, String>{
  'EUR': '€',
  'USD': '\$',
  'GBP': '£',
  'JPY': '¥',
  'CNY': '¥',
  'MYR': 'RM',
  'SGD': 'S\$',
  'AUD': 'A\$',
  'THB': '฿',
  'KRW': '₩',
  'HKD': 'HK\$',
  'TWD': 'NT\$',
};

/// `€4,207` — rounded, grouped, no decimals, as every figure in the design.
String formatMoney(num value, String currency) {
  final symbol = _symbols[currency.toUpperCase()];
  final rounded = value.round().abs();
  final grouped = rounded.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
  final sign = value < 0 ? '−' : '';
  if (symbol == null) return '$sign$grouped ${currency.toUpperCase()}';

  // Word-like symbols read as a prefix and need the space — "RM 1,182", not
  // "RM1,182". Single glyphs sit flush: "€4,200".
  final space = symbol.length > 1 ? ' ' : '';
  return '$sign$symbol$space$grouped';
}

/// A block's cost cell: an amount, or "free" when there's nothing to pay.
String formatBlockCost(num? value, String currency) {
  if (value == null || value == 0) return 'free';
  return '${formatMoney(value, currency)} pp';
}

/// `12 Sept` — the day-chip subtitle and header date range.
String formatShortDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  return '${date.day} ${_months[date.month - 1]}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec',
];

/// `4 August` — provenance lines, where the month is read rather than scanned
/// and the abbreviation would only save two characters.
String formatLongDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  return '${local.day} ${_longMonths[local.month - 1]}';
}

const _longMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Up to two initials, uppercased — `Maya Okonkwo` → `MO`.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

Color timeOfDayColor(plan_models.TimeOfDay time) => switch (time) {
      plan_models.TimeOfDay.morning => WayfareColors.morning,
      plan_models.TimeOfDay.afternoon => WayfareColors.afternoon,
      plan_models.TimeOfDay.evening => WayfareColors.evening,
    };

/// `Lisbon → Sintra → Porto · 12 Sept–16 Sept`
String destinationsSubtitle(
  List<String> destinations,
  String? start,
  String? end,
) {
  final route = destinations.join(' → ');
  final dates = [formatShortDate(start), formatShortDate(end)]
      .where((d) => d.isNotEmpty)
      .join('–');
  return [route, dates].where((s) => s.isNotEmpty).join(' · ');
}

/// `2026-09-12T13:15:00` → `13:15`. Flight times are local to their airport,
/// so they are read straight off the string rather than parsed into a zone.
String timeOf(String iso) => iso.length >= 16 ? iso.substring(11, 16) : '';

/// `Sat 12 Sep`
String weekdayAndDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  return '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `1h 15m`, or `45m` under an hour.
String formatDuration(num minutes) {
  final total = minutes.round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
