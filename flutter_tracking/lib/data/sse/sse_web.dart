import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sse.dart';

/// Implémentation web basée sur l'EventSource natif du navigateur.
Stream<SseEvent> connectSse(Uri uri) {
  web.EventSource? source;
  late final StreamController<SseEvent> controller;

  void close() {
    source?.close();
    source = null;
    if (!controller.isClosed) controller.close();
  }

  controller = StreamController<SseEvent>(
    onListen: () {
      final es = web.EventSource(uri.toString());
      source = es;
      for (final name in rtdbSseEvents) {
        es.addEventListener(
          name,
          ((web.MessageEvent e) {
            if (controller.isClosed) return;
            final data = e.data.dartify()?.toString() ?? 'null';
            controller.add((event: name, data: data));
          }).toJS,
        );
      }
      // L'EventSource se reconnecte seul, mais on préfère maîtriser le backoff
      // et signaler la perte de connexion à l'UI.
      es.onerror = ((web.Event _) {
        if (!controller.isClosed) controller.addError(StateError('Connexion temps réel interrompue'));
        close();
      }).toJS;
    },
    onCancel: close,
  );
  return controller.stream;
}
