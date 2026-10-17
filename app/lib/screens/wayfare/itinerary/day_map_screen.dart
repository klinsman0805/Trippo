import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../models/plan.dart';
import '../../../models/travel.dart';
import '../../../state/wayfare_controller.dart';
import '../formatting.dart';
import '../trip_tab.dart' show TravelConnector;

/// One day on a map: numbered pins in the order the day runs, with the day's
/// list in a sheet over it.
///
/// The list is the same day as the Trip tab — same order, same travel between
/// stops — so the map answers the one question the list cannot: where these
/// are relative to each other. Choosing a stop in either place shows it in the
/// other. A stop that could not be placed stays in the list, said to be off
/// the map; it is never given a pin it has not earned.
class DayMapScreen extends StatefulWidget {
  const DayMapScreen({super.key, required this.controller});

  final WayfareController controller;

  @override
  State<DayMapScreen> createState() => _DayMapScreenState();
}

class _DayMapScreenState extends State<DayMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final Map<String, GlobalKey> _rowKeys = {};

  /// Glides the camera to a chosen stop instead of jumping there, so the eye
  /// can follow which pin was meant.
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Animation<double>? _lat, _lng, _zoom;

  String? _selected;
  bool _mapReady = false;

  /// The day the camera was last framed for. A new day — or the same day once
  /// its points arrive — is framed again; a selection is not undone by it.
  String? _framedFor;

  WayfareController get controller => widget.controller;

  static const _sheetSizes = [0.16, 0.42, 0.9];

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    _flight.addListener(() {
      final lat = _lat, lng = _lng, zoom = _zoom;
      if (lat == null || lng == null || zoom == null) return;
      _map.move(LatLng(lat.value, lng.value), zoom.value);
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    _flight.dispose();
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = controller.currentDay;
    if (day == null) return const SizedBox.shrink();

    controller.ensurePointsFor(day);
    controller.ensureTravelFor(day);
    final points = controller.pointsOn(day);
    final failed = controller.pointsFailedOn(day);
    final chain = controller.travelChainOn(day);
    final order = controller.mapOrderOn(day);

    if (points != null) _frameOnce(day, points, chain);

    return Scaffold(
      backgroundColor: WayfareColors.bgApp,
      body: Stack(
        children: [
          Positioned.fill(child: _mapLayer(points, chain, order)),
          _topBar(context, day, points),
          if (failed)
            _notice(
              "Couldn't load where these are.",
              action: 'Try again',
              onAction: () => controller.retryPointsFor(day),
            )
          else if (points == null)
            _notice('Finding this day’s places…', busy: true)
          else if (!points.anyPlaced && order.isNotEmpty)
            _notice(
              'None of this day’s stops could be placed on a map. '
              'Give one an address and it appears here.',
            ),
          _sheetLayer(context, day, points, chain, order),
        ],
      ),
    );
  }

  // --- the map ---

  Widget _mapLayer(DayPoints? points, List<PlanBlock> chain, List<PlanBlock> order) {
    LatLng? at(PlanBlock b) {
      final p = points?.points[b.id];
      return p != null && p.isPlaced ? LatLng(p.lat!, p.lng!) : null;
    }

    final route = [for (final b in chain) ?at(b)];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: const LatLng(0, 0),
        initialZoom: 2,
        backgroundColor: const Color(0xFFE9E4DA),
        onMapReady: () {
          _mapReady = true;
          // Points may already be here from an earlier visit.
          if (mounted) setState(() {});
        },
        // A tap on the map itself lets go of the chosen stop.
        onTap: (_, _) => setState(() => _selected = null),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // OSM's own tile servers: right for development and testing, wrong
        // for a release. Their usage policy rules out heavy app traffic, so
        // before shipping this becomes a keyed provider (MapTiler, Stadia,
        // Protomaps) — a URL change here and nothing else.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.trippo',
          maxNativeZoom: 19,
        ),
        // The order the day runs, not the streets it runs along — a route
        // would claim knowledge of the path that these points do not have.
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                strokeWidth: 3,
                color: WayfareColors.accent.withValues(alpha: 0.75),
                pattern: StrokePattern.dashed(segments: const [10, 7]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final block in order)
              if (at(block) case final point?)
                Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  child: _Pin(
                    number: _numberOf(block, chain),
                    selected: block.id == _selected,
                    label: block.activity,
                    onTap: () => _choose(block.id, fromMap: true),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  int? _numberOf(PlanBlock block, List<PlanBlock> chain) {
    final i = chain.indexWhere((b) => b.id == block.id);
    return i < 0 ? null : i + 1;
  }

  /// Fit every pin into the part of the map the sheet leaves visible.
  void _frameOnce(PlanDay day, DayPoints points, List<PlanBlock> chain) {
    final key = '${day.day}:${points.points.length}:${points.anyPlaced}';
    if (!_mapReady || _framedFor == key) return;
    _framedFor = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final placed = [
        for (final p in points.points.values)
          if (p.isPlaced) LatLng(p.lat!, p.lng!),
      ];
      final padding = _visiblePadding(context);

      if (placed.length >= 2) {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: placed,
          padding: padding,
          maxZoom: 16,
        ));
      } else if (placed.length == 1) {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: placed,
          padding: padding,
          maxZoom: 15,
        ));
      } else if (points.anchorLat != null && points.anchorLng != null) {
        _map.move(LatLng(points.anchorLat!, points.anchorLng!), 12);
      }
    });
  }

  /// The map area not covered by the top bar or the sheet.
  EdgeInsets _visiblePadding(BuildContext context) {
    final media = MediaQuery.of(context);
    final sheet = (_sheet.isAttached ? _sheet.size : _sheetSizes[1]) *
        media.size.height;
    return EdgeInsets.fromLTRB(48, media.padding.top + 110, 48, sheet + 36);
  }

  // --- choosing a stop ---

  void _choose(String blockId, {bool fromMap = false}) {
    setState(() => _selected = blockId);

    final day = controller.currentDay;
    final point = day == null ? null : controller.pointsOn(day)?.points[blockId];
    if (point != null && point.isPlaced) {
      _flyTo(LatLng(point.lat!, point.lng!));
    }

    if (fromMap) {
      // The row the pin belongs to has to be on screen, or the tap went
      // nowhere the traveller can see.
      if (_sheet.isAttached && _sheet.size < _sheetSizes[1] - 0.01) {
        _sheet.animateTo(
          _sheetSizes[1],
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      final row = _rowKeys[blockId]?.currentContext;
      if (row != null) {
        Scrollable.ensureVisible(
          row,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      }
    }
  }

  void _flyTo(LatLng target) {
    if (!_mapReady) return;
    final camera = _map.camera;

    // Already in view: the accent on the pin says which one is meant, and
    // moving the map anyway would push its neighbours off screen for nothing.
    final at = camera.latLngToScreenOffset(target);
    final clear = _visiblePadding(context);
    if (at.dx >= clear.left &&
        at.dx <= camera.size.width - clear.right &&
        at.dy >= clear.top &&
        at.dy <= camera.size.height - clear.bottom) {
      return;
    }

    // Pan, keeping the zoom, while the view is already city-sized: the point
    // of choosing a stop is to see it among the others, and zooming to street
    // level throws the others off screen. Only a wider view zooms in.
    final zoom = camera.zoom >= 13 ? camera.zoom : 14.0;
    // Where the target would sit with the sheet's height kept clear — worked
    // out by the same fitting the opening frame uses, then flown to.
    final goal = CameraFit.coordinates(
      coordinates: [target],
      padding: _visiblePadding(context),
      maxZoom: zoom,
      minZoom: zoom,
    ).fit(camera);

    final curve = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    _lat = Tween(begin: camera.center.latitude, end: goal.center.latitude)
        .animate(curve);
    _lng = Tween(begin: camera.center.longitude, end: goal.center.longitude)
        .animate(curve);
    _zoom = Tween(begin: camera.zoom, end: goal.zoom).animate(curve);
    _flight.forward(from: 0);
  }

  // --- chrome ---

  Widget _topBar(BuildContext context, PlanDay day, DayPoints? points) {
    final theme = WayfareTheme.of(context);
    final date = formatShortDate(day.date);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RoundButton(
                    icon: theme.isAndroid ? Icons.arrow_back : Icons.chevron_left,
                    label: 'Back to the day',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: _Chip(
                      text: date.isEmpty ? 'Day ${day.day}' : 'Day ${day.day} · $date',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ODbL: the credit for the map and the places on it. On a line
              // of its own, so it never squeezes the day's name.
              Align(
                alignment: Alignment.centerRight,
                child: _Chip(
                  text: points?.attribution ?? '© OpenStreetMap contributors',
                  small: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, {bool busy = false, String? action, VoidCallback? onAction}) {
    return Positioned(
      left: 24,
      right: 24,
      top: MediaQuery.paddingOf(context).top + 98,
      child: Center(
        child: Material(
          color: WayfareColors.surface,
          elevation: 2,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WayfareColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 13.5, color: WayfareColors.ink),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: onAction,
                    child: Text(
                      action,
                      style: const TextStyle(color: WayfareColors.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- the sheet ---

  Widget _sheetLayer(
    BuildContext context,
    PlanDay day,
    DayPoints? points,
    List<PlanBlock> chain,
    List<PlanBlock> order,
  ) {
    final theme = WayfareTheme.of(context);
    final days = controller.plan?.itinerary ?? const <PlanDay>[];

    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: _sheetSizes[1],
      minChildSize: _sheetSizes.first,
      maxChildSize: _sheetSizes.last,
      snap: true,
      snapSizes: _sheetSizes,
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: WayfareColors.bgApp,
          borderRadius: BorderRadius.vertical(top: theme.cardLg.topLeft),
          boxShadow: const [
            BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, -2)),
          ],
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            const _Handle(),
            if (days.length > 1) ...[
              _DaySwitcher(
                days: days,
                selected: day.day.toInt(),
                onSelect: (n) {
                  setState(() => _selected = null);
                  controller.selectDay(n);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (order.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing planned on this day yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: WayfareColors.muted),
                ),
              ),
            for (final block in order) ...[
              if (_numberOf(block, chain) case final n? when n > 1)
                TravelConnector(leg: controller.legInto(day, block)),
              _StopRow(
                key: _rowKeys.putIfAbsent(block.id, GlobalKey.new),
                block: block,
                number: _numberOf(block, chain),
                // Unknown until the points arrive; only a known miss is said.
                offMap: points != null && !(points.points[block.id]?.isPlaced ?? false),
                selected: block.id == _selected,
                onTap: () => _choose(block.id),
              ),
              const SizedBox(height: WayfareSpace.cardGap),
            ],
          ],
        ),
      ),
    );
  }
}

/// A numbered stop. Accent when chosen, and a size up, so the one being talked
/// about is never in doubt.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.number,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  /// Null for an `anytime` stop, which has no place in the day's order.
  final int? number;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 38.0 : 30.0;
    return Semantics(
      button: true,
      label: number == null ? label : 'Stop $number: $label',
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? WayfareColors.accent : WayfareColors.ink,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              number?.toString() ?? '•',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: selected ? 15 : 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One stop in the sheet: its number, what it is, and when.
class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.block,
    required this.number,
    required this.offMap,
    required this.selected,
    required this.onTap,
  });

  final PlanBlock block;
  final int? number;
  final bool offMap;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final when = block.startTime != null
        ? formatClock(block.startTime!)
        : '${block.timeOfDay.name[0].toUpperCase()}${block.timeOfDay.name.substring(1)}';
    final venue = block.location.trim();
    final showVenue =
        venue.isNotEmpty && venue.toLowerCase() != block.activity.trim().toLowerCase();

    return Material(
      color: selected ? WayfareColors.surface : WayfareColors.surface.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: theme.card,
        side: BorderSide(
          color: selected ? WayfareColors.accent : const Color(0xFFEAE0D0),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: offMap
                      ? WayfareColors.paceChipBg
                      : selected
                          ? WayfareColors.accent
                          : WayfareColors.ink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number?.toString() ?? '•',
                  style: TextStyle(
                    color: offMap ? WayfareColors.muted : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.activity,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [when, if (showVenue) venue].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: WayfareColors.mutedLight,
                      ),
                    ),
                    if (offMap) ...[
                      const SizedBox(height: 5),
                      const Row(
                        children: [
                          Icon(Icons.location_off_outlined,
                              size: 13, color: WayfareColors.mutedLight),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              "Not on the map — couldn't place it",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: WayfareColors.mutedLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySwitcher extends StatelessWidget {
  const _DaySwitcher({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<PlanDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = days[i].day.toInt();
          final on = day == selected;
          return Semantics(
            selected: on,
            button: true,
            child: GestureDetector(
              onTap: () => onSelect(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? WayfareColors.ink : WayfareColors.surface,
                  borderRadius: theme.chip,
                  border: Border.all(
                    color: on ? WayfareColors.ink : const Color(0xFFE2D9CB),
                  ),
                ),
                child: Text(
                  'Day $day',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : WayfareColors.inkSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD5CBBB),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: WayfareColors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: const Color(0x33000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 24, color: WayfareColors.ink),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 14, vertical: small ? 4 : 10),
      decoration: BoxDecoration(
        color: WayfareColors.surface.withValues(alpha: small ? 0.85 : 1),
        borderRadius: BorderRadius.circular(small ? 8 : 22),
        boxShadow: small
            ? null
            : const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: small ? 10.5 : 14,
          fontWeight: small ? FontWeight.w400 : FontWeight.w700,
          color: small ? WayfareColors.muted : WayfareColors.ink,
        ),
      ),
    );
  }
}
