import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/status.dart';
import '../core/theme.dart';
import '../data/geocoding_service.dart';
import '../models/constatateur.dart';
import '../state/tracking_controller.dart';
import 'map_markers.dart';
import 'widgets/common.dart';

enum MapStyle {
  dark(Icons.dark_mode_rounded, 'Sombre'),
  light(Icons.light_mode_rounded, 'Plan');

  const MapStyle(this.icon, this.label);

  /// Fond OpenStreetMap "plan / rues", comme le front Angular. Le mode sombre
  /// est obtenu par filtre colorimétrique (aucune clé API requise).
  static const url = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final IconData icon;
  final String label;
}

/// Centre par défaut : Casablanca (comme le front Angular).
const defaultCenter = LatLng(33.5731, -7.5898);

class TrackingMap extends StatefulWidget {
  const TrackingMap({super.key, required this.controller, required this.overlayPadding});

  final TrackingController controller;

  /// Zones de l'écran recouvertes par les panneaux (recherche, fiche agent…),
  /// à éviter lors des recadrages.
  final EdgeInsets overlayPadding;

  @override
  State<TrackingMap> createState() => TrackingMapState();
}

class TrackingMapState extends State<TrackingMap> with TickerProviderStateMixin {
  final _map = MapController();
  MapStyle _style = MapStyle.light;
  bool _ready = false;
  bool _initialFitDone = false;
  AnimationController? _cameraAnim;

  // Animation des déplacements de marqueurs (450 ms, comme Leaflet côté Angular).
  late final AnimationController _markerAnim =
      AnimationController(vsync: this, value: 1, duration: const Duration(milliseconds: 450))..addListener(() {
        if (mounted) setState(() {});
      });
  final Map<String, LatLng> _from = {};
  final Map<String, LatLng> _to = {};

  String? _lastSelected;
  String? _lastHistoryKey;
  GeocodeResult? _lastPin;
  HistoriqueEntry? _lastFocused;

  TrackingController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onControllerChanged);
    _syncTargets();
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    _cameraAnim?.dispose();
    _markerAnim.dispose();
    _map.dispose();
    super.dispose();
  }

  // --- Réactions aux changements d'état ---------------------------------------

  void _onControllerChanged() {
    _syncTargets();
    if (!_ready) return;

    if (!_initialFitDone && c.loaded) {
      _initialFitDone = true;
      fitAll(animate: false);
    }

    if (c.selectedId != _lastSelected) {
      _lastSelected = c.selectedId;
      final sel = c.selected?.position;
      if (sel != null && !c.showHistory) {
        _animateTo(LatLng(sel.latitude, sel.longitude), zoom: _map.camera.zoom < 14 ? 15 : _map.camera.zoom);
      }
    }

    final historyKey = c.showHistory && c.history.isNotEmpty ? '${c.historyFor}' : null;
    if (historyKey != _lastHistoryKey) {
      _lastHistoryKey = historyKey;
      if (historyKey != null) _fitPoints([for (final h in c.history) LatLng(h.latitude, h.longitude)], maxZoom: 16);
    }

    if (c.geocodePin != _lastPin) {
      _lastPin = c.geocodePin;
      final pin = c.geocodePin;
      if (pin != null) _animateTo(pin.point, zoom: pin.zoom);
    }

    if (c.focusedEntry != _lastFocused) {
      _lastFocused = c.focusedEntry;
      final e = c.focusedEntry;
      if (e != null) _animateTo(LatLng(e.latitude, e.longitude), zoom: _map.camera.zoom < 16 ? 16 : _map.camera.zoom);
    }
  }

  /// Met à jour les positions cibles et lance l'interpolation des marqueurs.
  void _syncTargets() {
    final next = <String, LatLng>{};
    for (final a in c.agents) {
      final p = a.position;
      next[a.uid] = p != null ? LatLng(p.latitude, p.longitude) : (_to[a.uid] ?? defaultCenter);
    }
    var moved = false;
    for (final e in next.entries) {
      final prev = _to[e.key];
      if (prev != null && prev != e.value) moved = true;
      _from[e.key] = _current(e.key) ?? e.value;
    }
    _to
      ..clear()
      ..addAll(next);
    _from.removeWhere((k, _) => !next.containsKey(k));
    if (moved) {
      _markerAnim.forward(from: 0);
    } else if (!_markerAnim.isAnimating) {
      _markerAnim.value = 1;
    }
  }

  LatLng? _current(String uid) {
    final from = _from[uid];
    final to = _to[uid];
    if (from == null || to == null) return to;
    final t = Curves.easeOutCubic.transform(_markerAnim.value);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  // --- Caméra -----------------------------------------------------------------

  EdgeInsets get _fitPadding => widget.overlayPadding + const EdgeInsets.all(48);

  void fitAll({bool animate = true}) {
    final pts = [
      for (final a in c.agents)
        if (a.position != null) LatLng(a.position!.latitude, a.position!.longitude),
    ];
    if (pts.isEmpty) {
      _animateTo(defaultCenter, zoom: 12, animate: animate);
    } else if (pts.length == 1) {
      _animateTo(pts.first, zoom: 14, animate: animate);
    } else {
      _fitPoints(pts, maxZoom: 15, animate: animate);
    }
  }

  void zoomBy(double delta) => _animateTo(_map.camera.center, zoom: (_map.camera.zoom + delta).clamp(3, 19));

  void _fitPoints(List<LatLng> pts, {required double maxZoom, bool animate = true}) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _animateTo(pts.first, zoom: maxZoom - 1, animate: animate);
      return;
    }
    final target = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: _fitPadding,
      maxZoom: maxZoom,
    ).fit(_map.camera);
    _animateTo(target.center, zoom: target.zoom, animate: animate);
  }

  void _animateTo(LatLng dest, {required double zoom, bool animate = true}) {
    if (!_ready) return;
    _cameraAnim?.dispose();
    _cameraAnim = null;
    if (!animate) {
      _map.move(dest, zoom);
      return;
    }
    final cam = _map.camera;
    final lat = Tween(begin: cam.center.latitude, end: dest.latitude);
    final lng = Tween(begin: cam.center.longitude, end: dest.longitude);
    final z = Tween(begin: cam.zoom, end: zoom);
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    final curve = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);
    ctrl.addListener(() => _map.move(LatLng(lat.evaluate(curve), lng.evaluate(curve)), z.evaluate(curve)));
    _cameraAnim = ctrl;
    ctrl.forward();
  }

  void toggleStyle() => setState(() => _style = _style == MapStyle.dark ? MapStyle.light : MapStyle.dark);

  MapStyle get style => _style;

  // --- Rendu ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final history = c.showHistory ? c.history : const <HistoriqueEntry>[];
    final historyColor = c.historyFor != null ? AppColors.agent(c.historyFor!) : AppColors.green;
    final pin = c.geocodePin;

    // L'agent sélectionné est dessiné en dernier pour passer au-dessus.
    final ordered = [...c.agents]..sort((a, b) => (a.uid == c.selectedId ? 1 : 0) - (b.uid == c.selectedId ? 1 : 0));

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: defaultCenter,
        initialZoom: 12,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: _style == MapStyle.dark ? const Color(0xFF1B1B1B) : const Color(0xFFEDEDE8),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onMapReady: () {
          _ready = true;
          _onControllerChanged();
        },
        onTap: (_, _) {
          c.select(null);
          c.focusEntry(null);
        },
      ),
      children: [
        TileLayer(
          key: ValueKey(_style),
          urlTemplate: MapStyle.url,
          tileBuilder: _style == MapStyle.dark ? darkModeTileBuilder : null,
          userAgentPackageName: 'ma.newassist.tracking',
          maxZoom: 19,
        ),
        if (history.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [for (final h in history) LatLng(h.latitude, h.longitude)],
                strokeWidth: 4,
                gradientColors: [historyColor.withValues(alpha: 0.25), historyColor],
                borderStrokeWidth: 6,
                borderColor: Colors.white,
              ),
            ],
          ),
        if (history.isNotEmpty)
          CircleLayer(
            circles: [
              for (var i = 0; i < history.length; i++)
                CircleMarker(
                  point: LatLng(history[i].latitude, history[i].longitude),
                  radius: identical(history[i], c.focusedEntry) ? 9 : (i == history.length - 1 ? 7 : 4.5),
                  color: identical(history[i], c.focusedEntry)
                      ? Colors.white
                      : historyColor.withValues(alpha: 0.35 + 0.65 * (i + 1) / history.length),
                  borderColor: identical(history[i], c.focusedEntry) ? historyColor : Colors.white,
                  borderStrokeWidth: identical(history[i], c.focusedEntry) ? 3 : 1.5,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final a in ordered) _agentMarker(a),
            if (pin != null)
              Marker(
                point: pin.point,
                width: AccidentMarker.size.width,
                height: AccidentMarker.size.height,
                child: Tooltip(message: pin.label, child: const AccidentMarker()),
              ),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          popupBackgroundColor: AppColors.card,
          showFlutterMapAttribution: false,
          attributions: const [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Marker _agentMarker(Constatateur a) {
    final status = c.statusOf(a);
    return Marker(
      key: ValueKey(a.uid),
      point: _current(a.uid) ?? defaultCenter,
      width: AgentMarker.size.width,
      height: AgentMarker.size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => c.select(a.uid),
        child: AgentMarker(
          color: AppColors.agent(a.uid),
          name: a.infos.nom,
          hasPosition: a.position != null,
          offline: status.tone == StatusTone.offline,
          selected: a.uid == c.selectedId,
          phase: markerPhase(a.uid),
        ),
      ),
    );
  }
}

/// Contrôles flottants (zoom, recadrage, style de fond). En compact (mobile) :
/// rangée horizontale sans zoom (le pincement suffit).
class MapControls extends StatelessWidget {
  const MapControls({super.key, required this.mapKey, this.compact = false});

  final GlobalKey<TrackingMapState> mapKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 48.0;
    final fit = RoundIconButton(
      icon: Icons.my_location_rounded,
      tooltip: 'Voir tous les constatateurs',
      size: size,
      onPressed: () => mapKey.currentState?.fitAll(),
    );
    final style = StatefulBuilder(
      builder: (context, setState) {
        final current = mapKey.currentState?.style ?? MapStyle.light;
        final next = current == MapStyle.dark ? MapStyle.light : MapStyle.dark;
        return RoundIconButton(
          icon: next.icon,
          tooltip: 'Fond ${next.label}',
          size: size,
          onPressed: () {
            mapKey.currentState?.toggleStyle();
            setState(() {});
          },
        );
      },
    );
    if (compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [fit, const SizedBox(width: 8), style]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom avant',
          size: size,
          onPressed: () => mapKey.currentState?.zoomBy(1),
        ),
        const SizedBox(height: 8),
        RoundIconButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom arrière',
          size: size,
          onPressed: () => mapKey.currentState?.zoomBy(-1),
        ),
        const SizedBox(height: 16),
        fit,
        const SizedBox(height: 8),
        style,
      ],
    );
  }
}
