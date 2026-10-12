# NewAssist · Live Tracking (Flutter)

Migration Flutter du front Angular (`../src`) : suivi temps réel des constatateurs sur carte.

## Lancer

```bash
cd flutter_tracking
flutter pub get
flutter run -d chrome          # web
flutter run -d windows         # desktop (Visual Studio requis)
flutter run                    # Android / iOS
flutter test                   # tests unitaires
flutter build web --release    # build de production -> build/web
```

URL de la Realtime Database surchargeable : `--dart-define=RTDB_URL=https://<projet>.firebaseio.com`.

## Correspondance Angular → Flutter

| Angular | Flutter |
|---|---|
| `environments/environment.ts` | `lib/core/config.dart` |
| `models/constatateur.model.ts` | `lib/models/constatateur.dart` |
| `utils/constatateur-status.util.ts` | `lib/core/status.dart` |
| `services/constatateurs.service.ts` (@angular/fire) | `lib/data/rtdb_client.dart` (REST + streaming SSE) |
| Géocodage Nominatim (map.component) | `lib/data/geocoding_service.dart` |
| `app.component.ts` (état, signals) | `lib/state/tracking_controller.dart` (ChangeNotifier) |
| `sidebar.component` | `lib/ui/sidebar.dart` |
| `map.component` (Leaflet) | `lib/ui/map_view.dart`, `lib/ui/map_markers.dart` (flutter_map) |
| `history-panel.component`, modale distances | `lib/ui/panels.dart` |

## Notes techniques

- **Firebase** : la base est lue via l'API REST de la Realtime Database (`.json` + `text/event-stream`),
  sans FlutterFire, car le projet n'expose ni `apiKey` ni `appId`. Reconnexion automatique (backoff
  jusqu'à 30 s) et relecture de secours toutes les 30 s, comme le `timer` Angular. La pastille
  « Temps réel » reflète l'état du flux SSE (remplace `.info/connected`).
- **Règles inchangées** : statut « HORS LIGNE » si la dernière position a plus de 5 min, couleurs
  d'agents identiques (même hash d'uid, vérifié par test), historique limité aux 50 derniers points.
- **Carte** : tuiles OpenStreetMap (fond clair par défaut) ; le mode sombre est un filtre colorimétrique (pas de clé API).
  Pour un usage intensif en production, prévoir un fournisseur de tuiles dédié
  ([politique d'usage OSM](https://operations.osmfoundation.org/policies/tiles/)).

## Design

Style « app de livraison » (inspiré de Glovo, sans reprise de marque) : thème clair, jaune `#FFC244`
et vert `#00A082`, police Nunito, cartes blanches très arrondies, bulles de catégories rondes,
épingles à initiales sur la carte. Tokens dans `lib/core/theme.dart`.

## Nouveautés UX

KPI cliquables servant de filtres de statut, recherche par nom, fiche agent flottante (batterie,
vitesse, mode, précision), historique en frise cliquable avec tracé en dégradé, classement des
constatateurs par distance cliquable, fond sombre / clair, mise en page responsive (sur mobile : carte plein écran + feuille glissante).
