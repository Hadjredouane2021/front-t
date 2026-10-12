// Modèles miroir de src/app/models/constatateur.model.ts (front Angular).

enum StatutConstatateur {
  disponible('DISPONIBLE'),
  enMission('EN_MISSION'),
  indisponible('INDISPONIBLE');

  const StatutConstatateur(this.raw);
  final String raw;

  static StatutConstatateur parse(Object? value) {
    final s = value?.toString().toUpperCase();
    return StatutConstatateur.values.firstWhere((e) => e.raw == s, orElse: () => StatutConstatateur.indisponible);
  }
}

enum ModeTracking {
  stationnaire('STATIONNAIRE'),
  enMouvement('EN_MOUVEMENT');

  const ModeTracking(this.raw);
  final String raw;

  static ModeTracking parse(Object? value) =>
      value?.toString().toUpperCase() == 'EN_MOUVEMENT' ? ModeTracking.enMouvement : ModeTracking.stationnaire;
}

double _toDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
Map<String, dynamic> _asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

class InfosConstatateur {
  const InfosConstatateur({
    required this.nom,
    required this.statut,
    required this.actif,
    required this.telephone,
    required this.androidId,
  });

  factory InfosConstatateur.fromJson(Object? raw) {
    final j = _asMap(raw);
    return InfosConstatateur(
      nom: (j['nom'] ?? '').toString(),
      statut: StatutConstatateur.parse(j['statut']),
      actif: j['actif'] == true,
      telephone: (j['telephone'] ?? '').toString(),
      androidId: (j['androidId'] ?? '').toString(),
    );
  }

  final String nom;
  final StatutConstatateur statut;
  final bool actif;
  final String telephone;
  final String androidId;

  @override
  bool operator ==(Object other) =>
      other is InfosConstatateur &&
      other.nom == nom &&
      other.statut == statut &&
      other.actif == actif &&
      other.telephone == telephone &&
      other.androidId == androidId;

  @override
  int get hashCode => Object.hash(nom, statut, actif, telephone, androidId);
}

class PositionActuelle {
  const PositionActuelle({
    required this.latitude,
    required this.longitude,
    required this.modeTracking,
    required this.niveauBatterie,
    required this.vitesse,
    required this.precision,
    required this.timestamp,
  });

  static PositionActuelle? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return PositionActuelle(
      latitude: _toDouble(j['latitude']),
      longitude: _toDouble(j['longitude']),
      modeTracking: ModeTracking.parse(j['modeTracking']),
      niveauBatterie: _toInt(j['niveauBatterie']),
      vitesse: _toDouble(j['vitesse']),
      precision: _toDouble(j['precision']),
      timestamp: _toInt(j['timestamp']),
    );
  }

  final double latitude;
  final double longitude;
  final ModeTracking modeTracking;
  final int niveauBatterie;

  /// Vitesse en m/s (comme remontée par l'app Android).
  final double vitesse;
  final double precision;

  /// Epoch en millisecondes.
  final int timestamp;

  double get vitesseKmh => vitesse * 3.6;

  @override
  bool operator ==(Object other) =>
      other is PositionActuelle &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.modeTracking == modeTracking &&
      other.niveauBatterie == niveauBatterie &&
      other.vitesse == vitesse &&
      other.precision == precision &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(latitude, longitude, modeTracking, niveauBatterie, vitesse, precision, timestamp);
}

class HistoriqueEntry {
  const HistoriqueEntry({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.modeTracking,
    required this.niveauBatterie,
    required this.vitesse,
    required this.timestamp,
  });

  factory HistoriqueEntry.fromJson(String id, Object? raw) {
    final j = _asMap(raw);
    return HistoriqueEntry(
      id: id,
      latitude: _toDouble(j['latitude']),
      longitude: _toDouble(j['longitude']),
      modeTracking: ModeTracking.parse(j['modeTracking']),
      niveauBatterie: _toInt(j['niveauBatterie']),
      vitesse: _toDouble(j['vitesse']),
      timestamp: _toInt(j['timestamp']),
    );
  }

  final String id;
  final double latitude;
  final double longitude;
  final ModeTracking modeTracking;
  final int niveauBatterie;
  final double vitesse;
  final int timestamp;

  double get vitesseKmh => vitesse * 3.6;
}

class Constatateur {
  const Constatateur({required this.uid, required this.infos, required this.position});

  final String uid;
  final InfosConstatateur infos;
  final PositionActuelle? position;

  @override
  bool operator ==(Object other) =>
      other is Constatateur && other.uid == uid && other.infos == infos && other.position == position;

  @override
  int get hashCode => Object.hash(uid, infos, position);
}

/// Convertit le nœud `constatateurs` de la Realtime Database en liste.
List<Constatateur> parseConstatateurs(Object? raw) {
  if (raw is! Map) return const [];
  return [
    for (final e in raw.entries)
      if (e.value is Map)
        Constatateur(
          uid: e.key.toString(),
          infos: InfosConstatateur.fromJson((e.value as Map)['infos']),
          position: PositionActuelle.fromJson((e.value as Map)['position_actuelle']),
        ),
  ];
}

/// Convertit `constatateurs/{uid}/historique` en liste triée chronologiquement.
List<HistoriqueEntry> parseHistorique(Object? raw) {
  final entries = <HistoriqueEntry>[];
  if (raw is Map) {
    raw.forEach((k, v) => entries.add(HistoriqueEntry.fromJson(k.toString(), v)));
  } else if (raw is List) {
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] != null) entries.add(HistoriqueEntry.fromJson('$i', raw[i]));
    }
  }
  entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return entries;
}
