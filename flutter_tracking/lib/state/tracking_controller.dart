import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/status.dart';
import '../data/geocoding_service.dart';
import '../data/rtdb_client.dart';
import '../models/constatateur.dart';

enum StatusFilter { all, available, mission, unavailable, offline }

class AgentDistance {
  const AgentDistance(this.agent, this.meters, this.status);
  final Constatateur agent;
  final double meters;
  final EffectiveStatus status;
}

class SearchOutcome {
  const SearchOutcome(this.result, this.distances);
  final GeocodeResult result;
  final List<AgentDistance> distances;
}

/// État global de l'écran de suivi (équivalent de AppComponent côté Angular).
class TrackingController extends ChangeNotifier {
  TrackingController({RtdbClient? db, GeocodingService? geocoder})
    : db = db ?? RtdbClient(AppConfig.databaseUrl),
      _geocoder = geocoder ?? GeocodingService();

  final RtdbClient db;
  final GeocodingService _geocoder;
  static const _distance = Distance(calculator: Haversine());

  List<Constatateur> _agents = const [];
  String? _selectedId;
  String? _historyFor;
  List<HistoriqueEntry> _history = const [];
  bool _historyLoading = false;
  String? _error;
  bool _loaded = false;
  bool _sidebarOpen = true;
  String _query = '';
  StatusFilter _filter = StatusFilter.all;
  DateTime _now = DateTime.now();
  GeocodeResult? _geocodePin;
  HistoriqueEntry? _focusedEntry;

  StreamSubscription<Object?>? _agentsSub;
  StreamSubscription<Object?>? _historySub;
  Timer? _refreshTimer;
  Timer? _clock;

  // --- Getters --------------------------------------------------------------

  List<Constatateur> get agents => _agents;
  String? get selectedId => _selectedId;
  Constatateur? get selected => _agents.firstWhereOrNull((c) => c.uid == _selectedId);
  String? get historyFor => _historyFor;
  Constatateur? get historyAgent => _agents.firstWhereOrNull((c) => c.uid == _historyFor);
  List<HistoriqueEntry> get history => _history;
  bool get historyLoading => _historyLoading;
  bool get showHistory => _historyFor != null;
  String? get error => _error;
  bool get loaded => _loaded;
  bool get sidebarOpen => _sidebarOpen;
  bool get connected => db.connected.value;
  String get query => _query;
  StatusFilter get filter => _filter;
  DateTime get now => _now;
  GeocodeResult? get geocodePin => _geocodePin;
  HistoriqueEntry? get focusedEntry => _focusedEntry;

  EffectiveStatus statusOf(Constatateur c) => effectiveStatus(c, _now);

  /// Liste triée par nom (fr, insensible à la casse), filtrée par recherche + statut.
  List<Constatateur> get visibleAgents {
    final q = _query.trim().toLowerCase();
    return _agents.where((c) {
      if (q.isNotEmpty && !c.infos.nom.toLowerCase().contains(q) && !c.infos.telephone.contains(q)) return false;
      if (_filter == StatusFilter.all) return true;
      return statusOf(c).tone.name == _filter.name;
    }).toList();
  }

  Map<StatusTone, int> get toneCounts {
    final counts = {for (final t in StatusTone.values) t: 0};
    for (final c in _agents) {
      counts.update(statusOf(c).tone, (v) => v + 1);
    }
    return counts;
  }

  // --- Cycle de vie -----------------------------------------------------------

  void start() {
    db.connected.addListener(notifyListeners);
    _agentsSub = db
        .watch('constatateurs')
        .listen(
          (raw) => _applySnapshot(parseConstatateurs(raw)),
          onError: (Object e) => _setError(
            e is RtdbException ? e.message : 'Lecture Firebase refusée. Vérifie les règles Realtime Database.',
          ),
        );
    _refreshTimer = Timer.periodic(AppConfig.refreshInterval, (_) => refresh());
    // Recalcule les statuts effectifs (HORS LIGNE après 5 min) et les âges relatifs.
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
    refresh();
  }

  /// Lecture ponctuelle de secours (le flux SSE peut être coupé par un proxy).
  Future<void> refresh() async {
    try {
      _applySnapshot(parseConstatateurs(await db.get('constatateurs')));
    } catch (e) {
      _setError(e is RtdbException ? e.message : 'Impossible de joindre Firebase.');
    }
  }

  @override
  void dispose() {
    _agentsSub?.cancel();
    _historySub?.cancel();
    _refreshTimer?.cancel();
    _clock?.cancel();
    db.connected.removeListener(notifyListeners);
    db.dispose();
    super.dispose();
  }

  // --- Actions UI -------------------------------------------------------------

  void select(String? uid) {
    if (_selectedId == uid) return;
    _selectedId = uid;
    notifyListeners();
  }

  void toggleSidebar() {
    _sidebarOpen = !_sidebarOpen;
    notifyListeners();
  }

  void setSidebar(bool open) {
    if (_sidebarOpen == open) return;
    _sidebarOpen = open;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void setFilter(StatusFilter f) {
    _filter = _filter == f ? StatusFilter.all : f;
    notifyListeners();
  }

  void dismissError() {
    _error = null;
    notifyListeners();
  }

  void openHistory(String uid) {
    _selectedId = uid;
    _historyFor = uid;
    _focusedEntry = null;
    _history = const [];
    _historyLoading = true;
    notifyListeners();
    _historySub?.cancel();
    _historySub = db
        .watch(
          'constatateurs/$uid/historique',
          query: {'orderBy': r'"$key"', 'limitToLast': '${AppConfig.historyLimit}'},
        )
        .listen(
          (raw) {
            _history = parseHistorique(raw);
            _historyLoading = false;
            notifyListeners();
          },
          onError: (Object _) {
            _historyLoading = false;
            _setError("Impossible de lire l'historique Firebase.");
          },
        );
  }

  void focusEntry(HistoriqueEntry? entry) {
    _focusedEntry = entry;
    notifyListeners();
  }

  void closeHistory() {
    _focusedEntry = null;
    _historySub?.cancel();
    _historySub = null;
    _historyFor = null;
    _history = const [];
    _historyLoading = false;
    notifyListeners();
  }

  /// Géocode l'adresse puis classe les constatateurs par distance.
  Future<SearchOutcome> searchAddress(String query) async {
    final result = await _geocoder.search(query);
    _geocodePin = result;
    notifyListeners();
    final distances =
        _agents
            .where((c) => c.position != null)
            .map(
              (c) => AgentDistance(
                c,
                _distance.as(LengthUnit.Meter, result.point, LatLng(c.position!.latitude, c.position!.longitude)),
                statusOf(c),
              ),
            )
            .toList()
          ..sort((a, b) => a.meters.compareTo(b.meters));
    if (distances.isEmpty) {
      throw const GeocodeException('Aucune position de constatateur disponible pour calculer la distance.');
    }
    return SearchOutcome(result, distances);
  }

  void clearGeocodePin() {
    _geocodePin = null;
    notifyListeners();
  }

  // --- Interne ----------------------------------------------------------------

  void _setError(String message) {
    if (_error == message) return;
    _error = message;
    notifyListeners();
  }

  /// Ne notifie que si les données ont réellement changé (évite de reconstruire
  /// la carte et la liste quand rien n'a bougé), comme applyConstatateursSnapshot.
  void _applySnapshot(List<Constatateur> incoming) {
    incoming.sort((a, b) => _frCompare(a.infos.nom, b.infos.nom));
    final changed = !_loaded || _error != null || !const ListEquality<Constatateur>().equals(_agents, incoming);
    _loaded = true;
    _error = null;
    if (!changed) return;
    _agents = List.unmodifiable(incoming);
    notifyListeners();
  }

  static int _frCompare(String a, String b) => _fold(a).compareTo(_fold(b));

  static String _fold(String s) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i == -1 ? ch : to[i]);
    }
    return buf.toString();
  }
}
