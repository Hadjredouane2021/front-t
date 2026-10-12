import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sse/sse.dart';

class RtdbException implements Exception {
  const RtdbException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client minimal de la Firebase Realtime Database via son API REST :
/// lecture ponctuelle (`get`) et écoute temps réel (`watch`, streaming SSE).
///
/// Remplace @angular/fire sans nécessiter de configuration FlutterFire
/// (le projet n'expose ni apiKey ni appId, seulement l'URL de la base).
class RtdbClient {
  RtdbClient(this.baseUrl, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Vrai tant qu'au moins un flux temps réel reçoit des évènements.
  /// Remplace l'écoute de `.info/connected` du SDK JS.
  final ValueNotifier<bool> connected = ValueNotifier(false);
  int _liveStreams = 0;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl/$path.json');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Object?> get(String path, {Map<String, String>? query}) async {
    final res = await _http.get(_uri(path, query), headers: const {'Accept': 'application/json'});
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const RtdbException('Lecture Firebase refusée. Vérifie les règles Realtime Database.');
    }
    if (res.statusCode != 200) throw RtdbException('Firebase HTTP ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Émet la valeur complète du nœud à chaque modification, avec reconnexion
  /// automatique (backoff exponentiel plafonné à 30 s).
  Stream<Object?> watch(String path, {Map<String, String>? query}) {
    late final StreamController<Object?> out;
    StreamSubscription<SseEvent>? sub;
    Timer? retry;
    Object? tree;
    var attempt = 0;
    var live = false;
    var cancelled = false;

    void setLive(bool value) {
      if (live == value) return;
      live = value;
      _liveStreams += value ? 1 : -1;
      connected.value = _liveStreams > 0;
    }

    late void Function() connect;

    void scheduleReconnect() {
      setLive(false);
      if (cancelled) return;
      final delay = Duration(seconds: math.min(30, 1 << math.min(attempt, 5)));
      attempt++;
      retry = Timer(delay, connect);
    }

    connect = () {
      sub = connectSse(_uri(path, query)).listen(
        (ev) {
          switch (ev.event) {
            case 'put' || 'patch':
              final msg = jsonDecode(ev.data) as Map<String, dynamic>;
              final at = (msg['path'] ?? '/') as String;
              if (ev.event == 'put') {
                tree = rtdbSetAt(tree, at, msg['data']);
              } else {
                (msg['data'] as Map<String, dynamic>? ?? const {}).forEach(
                  (k, v) => tree = rtdbSetAt(tree, '$at/$k', v),
                );
              }
              attempt = 0;
              setLive(true);
              out.add(tree);
            case 'keep-alive':
              setLive(true);
            case 'cancel' || 'auth_revoked':
              out.addError(const RtdbException('Lecture Firebase refusée. Vérifie les règles Realtime Database.'));
          }
        },
        onError: (Object e) {
          if (!cancelled) debugPrint('RTDB stream $path: $e');
        },
        onDone: scheduleReconnect,
        cancelOnError: false,
      );
    };

    out = StreamController<Object?>(
      onListen: connect,
      onCancel: () async {
        cancelled = true;
        retry?.cancel();
        setLive(false);
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  void dispose() {
    _http.close();
    connected.dispose();
  }
}

/// Applique un `put` RTDB (remplacement de la valeur à `path`).
@visibleForTesting
Object? rtdbSetAt(Object? root, String path, Object? data) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return data;
  Map<String, dynamic> writable(Object? v) =>
      v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});
  final result = writable(root);
  var node = result;
  for (final seg in segments.take(segments.length - 1)) {
    final next = writable(node[seg]);
    node[seg] = next;
    node = next;
  }
  if (data == null) {
    node.remove(segments.last);
  } else {
    node[segments.last] = data;
  }
  return result;
}
