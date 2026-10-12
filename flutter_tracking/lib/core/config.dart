/// Équivalent de src/environments/environment.ts.
///
/// Projet Realtime Database position-fe298 (us-central1), nœud racine `constatateurs`.
/// Surchargeable au build : `--dart-define=RTDB_URL=https://...firebaseio.com`.
abstract final class AppConfig {
  static const databaseUrl = String.fromEnvironment(
    'RTDB_URL',
    defaultValue: 'https://position-fe298-default-rtdb.firebaseio.com',
  );

  /// Rafraîchissement de secours, comme le `timer(30_000, 30_000)` Angular.
  static const refreshInterval = Duration(seconds: 30);

  /// Taille de l'historique chargé (limitToLast).
  static const historyLimit = 50;

  static const userAgent = 'NewAssistTracking/1.0 (flutter)';
}
