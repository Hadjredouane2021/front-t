// Portage de src/app/utils/constatateur-status.util.ts.

import '../models/constatateur.dart';

/// Au-delà de ce délai, la dernière position remontée est considérée obsolète
/// et le constatateur est marqué "HORS LIGNE" quel que soit son statut déclaré.
const positionStale = Duration(minutes: 5);

enum StatusTone { available, mission, unavailable, offline }

class EffectiveStatus {
  const EffectiveStatus(this.label, this.tone, {required this.stale});

  final String label;
  final StatusTone tone;
  final bool stale;
}

bool isPositionStale(int? timestampMs, DateTime now) {
  if (timestampMs == null || timestampMs <= 0) return true;
  return now.millisecondsSinceEpoch - timestampMs > positionStale.inMilliseconds;
}

String statusLabel(StatutConstatateur statut) => switch (statut) {
  StatutConstatateur.disponible => 'DISPONIBLE',
  StatutConstatateur.enMission => 'EN MISSION',
  StatutConstatateur.indisponible => 'INDISPONIBLE',
};

StatusTone statusTone(StatutConstatateur statut) => switch (statut) {
  StatutConstatateur.disponible => StatusTone.available,
  StatutConstatateur.enMission => StatusTone.mission,
  StatutConstatateur.indisponible => StatusTone.unavailable,
};

/// Statut "effectif" affiché à l'utilisateur :
/// - si la dernière position est obsolète (ou absente), on bascule en HORS LIGNE,
/// - sinon on conserve le statut déclaré par l'agent.
EffectiveStatus effectiveStatus(Constatateur c, DateTime now) {
  if (isPositionStale(c.position?.timestamp, now)) {
    return const EffectiveStatus('HORS LIGNE', StatusTone.offline, stale: true);
  }
  return EffectiveStatus(statusLabel(c.infos.statut), statusTone(c.infos.statut), stale: false);
}

/// Âge relatif lisible ("il y a 12 min", "il y a 2 h", "il y a 3 j").
String relativeAge(int? timestampMs, DateTime now) {
  if (timestampMs == null || timestampMs <= 0) return 'inconnue';
  final diff = now.millisecondsSinceEpoch - timestampMs;
  if (diff < 0) return "à l'instant";
  final sec = (diff / 1000).round();
  if (sec < 60) return 'il y a ${sec}s';
  final min = (sec / 60).round();
  if (min < 60) return 'il y a $min min';
  final h = (min / 60).round();
  if (h < 24) return 'il y a $h h';
  return 'il y a ${(h / 24).round()} j';
}

String formatDistance(double meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '${meters.round()} m';

/// "Prenom Nom" à partir d'un nom complet ou d'un e-mail, en majuscules.
String shortAgentName(String raw) {
  final source = raw.trim();
  if (source.isEmpty) return 'CONSTATATEUR';
  final base = source.contains('@') ? source.split('@').first : source;
  final tokens = base.split(RegExp(r'[\s._-]+')).where((t) => t.isNotEmpty).toList();
  if (tokens.length >= 2) return '${tokens[0]} ${tokens[1]}'.toUpperCase();
  return (tokens.isEmpty ? 'CONSTATATEUR' : tokens.first).toUpperCase();
}

String initials(String raw) {
  final parts = shortAgentName(raw).split(' ');
  return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}' : parts.first.substring(0, parts.first.length.clamp(0, 2));
}
