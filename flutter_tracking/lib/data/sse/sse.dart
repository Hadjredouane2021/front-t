import 'sse_io.dart' if (dart.library.js_interop) 'sse_web.dart' as impl;

/// Un évènement Server-Sent Events (`event:` + `data:`).
typedef SseEvent = ({String event, String data});

/// Évènements émis par le streaming REST de la Realtime Database.
const rtdbSseEvents = ['put', 'patch', 'keep-alive', 'cancel', 'auth_revoked'];

/// Ouvre un flux SSE. Le flux se termine (onDone) ou échoue (onError) quand la
/// connexion tombe ; la reconnexion est gérée par l'appelant.
Stream<SseEvent> connectSse(Uri uri) => impl.connectSse(uri);
