import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:newassist_tracking/core/status.dart';
import 'package:newassist_tracking/core/theme.dart';
import 'package:newassist_tracking/data/rtdb_client.dart';
import 'package:newassist_tracking/models/constatateur.dart';
import 'package:newassist_tracking/ui/map_markers.dart';

void main() {
  group('Couleurs agents (parité avec le front Angular)', () {
    // Valeurs de référence calculées avec l'algorithme TypeScript (Math.imul).
    const refs = {
      'abc': (96354, 6, 25),
      'Xk29fLmQp0aZ': (1895246877, 9, 2),
      'uid-éàü': (436267064, 8, 31),
      'a7Hf3kLmN9pQrStUvWxYz012': (1759283892, 0, 5),
    };
    refs.forEach((uid, ref) {
      test(uid, () {
        expect(AppColors.hashUid(uid), ref.$1);
        expect(AppColors.agent(uid), AppColors.markerPalette[ref.$2]);
        expect(markerPhase(uid), ref.$3 / 100);
      });
    });
  });

  group('Statut effectif', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1_000_000_000);
    Constatateur agent(StatutConstatateur s, int? ts) => Constatateur(
          uid: 'u',
          infos: InfosConstatateur(nom: 'A', statut: s, actif: true, telephone: '', androidId: ''),
          position: ts == null
              ? null
              : PositionActuelle(
                  latitude: 0,
                  longitude: 0,
                  modeTracking: ModeTracking.stationnaire,
                  niveauBatterie: 50,
                  vitesse: 0,
                  precision: 0,
                  timestamp: ts,
                ),
        );

    test('position récente → statut déclaré', () {
      final s = effectiveStatus(agent(StatutConstatateur.enMission, now.millisecondsSinceEpoch - 60_000), now);
      expect(s.label, 'EN MISSION');
      expect(s.tone, StatusTone.mission);
      expect(s.stale, isFalse);
    });

    test('position > 5 min → HORS LIGNE', () {
      final s = effectiveStatus(agent(StatutConstatateur.disponible, now.millisecondsSinceEpoch - 5 * 60_000 - 1), now);
      expect(s.tone, StatusTone.offline);
      expect(s.label, 'HORS LIGNE');
    });

    test('sans position → HORS LIGNE', () {
      expect(effectiveStatus(agent(StatutConstatateur.disponible, null), now).tone, StatusTone.offline);
    });

    test('âge relatif', () {
      final t = now.millisecondsSinceEpoch;
      expect(relativeAge(null, now), 'inconnue');
      expect(relativeAge(t + 10, now), "à l'instant");
      expect(relativeAge(t - 12_000, now), 'il y a 12s');
      expect(relativeAge(t - 12 * 60_000, now), 'il y a 12 min');
      expect(relativeAge(t - 2 * 3_600_000, now), 'il y a 2 h');
      expect(relativeAge(t - 3 * 86_400_000, now), 'il y a 3 j');
    });
  });

  test('formatDistance / shortAgentName / initials', () {
    expect(formatDistance(850.4), '850 m');
    expect(formatDistance(1234), '1.23 km');
    expect(shortAgentName('jean.dupont@newassist.ma'), 'JEAN DUPONT');
    expect(shortAgentName('  '), 'CONSTATATEUR');
    expect(initials('Yassine El Amrani'), 'YE');
  });

  group('Application des évènements RTDB', () {
    test('put racine puis put/suppression imbriqués', () {
      // Même forme que la sortie de jsonDecode (Map<String, dynamic>).
      Object? tree = rtdbSetAt(null, '/', jsonDecode('{"a": {"infos": {"nom": "A"}}}'));
      tree = rtdbSetAt(tree, '/a/position_actuelle', jsonDecode('{"latitude": 33.5, "longitude": -7.6, "timestamp": 1}'));
      tree = rtdbSetAt(tree, '/b/infos/nom', 'B');
      expect(parseConstatateurs(tree).map((c) => c.uid), ['a', 'b']);
      expect(parseConstatateurs(tree).first.position?.latitude, 33.5);

      tree = rtdbSetAt(tree, '/b', null);
      expect(parseConstatateurs(tree).map((c) => c.uid), ['a']);
    });

    test('historique trié par timestamp', () {
      final h = parseHistorique({
        'k2': {'timestamp': 20, 'vitesse': 10},
        'k1': {'timestamp': 10, 'vitesse': 5, 'modeTracking': 'EN_MOUVEMENT'},
      });
      expect(h.map((e) => e.id), ['k1', 'k2']);
      expect(h.first.modeTracking, ModeTracking.enMouvement);
      expect(h.last.vitesseKmh, closeTo(36, 1e-9));
    });
  });
}
