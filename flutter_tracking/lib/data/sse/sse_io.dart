import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sse.dart';

/// Implémentation mobile / desktop basée sur dart:io.
Stream<SseEvent> connectSse(Uri uri) {
  HttpClient? client;
  late final StreamController<SseEvent> controller;

  Future<void> run() async {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client!.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('SSE HTTP ${response.statusCode}', uri: uri);
      }

      var event = 'message';
      final data = StringBuffer();
      await for (final line in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (data.isNotEmpty) controller.add((event: event, data: data.toString()));
          event = 'message';
          data.clear();
          continue;
        }
        if (line.startsWith(':')) continue;
        final idx = line.indexOf(':');
        final field = idx == -1 ? line : line.substring(0, idx);
        var value = idx == -1 ? '' : line.substring(idx + 1);
        if (value.startsWith(' ')) value = value.substring(1);
        if (field == 'event') {
          event = value;
        } else if (field == 'data') {
          if (data.isNotEmpty) data.write('\n');
          data.write(value);
        }
      }
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      client?.close(force: true);
      if (!controller.isClosed) await controller.close();
    }
  }

  controller = StreamController<SseEvent>(onListen: run, onCancel: () => client?.close(force: true));
  return controller.stream;
}
