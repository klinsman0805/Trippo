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
      // Not bound to a part of the day, so it gets the muted ink rather than
      // borrowing a slot colour it does not belong to.
      plan_models.TimeOfDay.anytime => WayfareColors.mutedLight,
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

/// `2026-09-12T13:15:00` → `1:15 PM`.
///
/// Flight times are local to their own airport, so the clock part is read
/// straight off the string rather than parsed into a zone — converting is what
/// would make a departure disagree with the boarding pass.
String timeOf(String iso) =>
    iso.length >= 16 ? formatClock(iso.substring(11, 16)) : '';

/// `18:45` → `6:45 PM`.
///
/// Times are stored 24-hour and shown 12-hour: one canonical form underneath
/// means nothing that sorts or compares them has to parse an AM/PM string,
/// and the reader still gets the format they think in.
String formatClock(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final hour = int.tryParse(parts[0]);
  final minute = parts[1].padLeft(2, '0');
  if (hour == null) return hhmm;

  final suffix = hour < 12 ? 'AM' : 'PM';
  // 0 and 12 both display as 12 — midnight is 12 AM, noon is 12 PM.
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display:$minute $suffix';
}

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
