import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

class GeocodeResult {
  const GeocodeResult({required this.point, required this.label, required this.type});

  final LatLng point;
  final String label;
  final String? type;

  /// Zoom adapté : plus serré pour un bâtiment précis.
  double get zoom => const {'house', 'building', 'shop'}.contains(type) ? 17 : 16;
}

class GeocodeException implements Exception {
  const GeocodeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Géocodage Nominatim (OpenStreetMap), limité au Maroc.
class GeocodingService {
  GeocodingService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  Future<GeocodeResult> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) throw const GeocodeException('Saisissez une adresse ou un lieu.');

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'ma',
      'addressdetails': '1',
    });

    final http.Response res;
    try {
      res = await _http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'fr',
          // Les navigateurs interdisent de surcharger le User-Agent.
          if (!kIsWeb) 'User-Agent': AppConfig.userAgent,
        },
      );
    } catch (_) {
      throw const GeocodeException('Impossible de contacter le service de géocodage.');
    }
    if (res.statusCode != 200) {
      throw const GeocodeException('Service de recherche indisponible. Réessayez plus tard.');
    }

    final raw = jsonDecode(utf8.decode(res.bodyBytes));
    final hit = raw is List && raw.isNotEmpty ? raw.first as Map<String, dynamic> : null;
    final lat = double.tryParse('${hit?['lat']}');
    final lon = double.tryParse('${hit?['lon']}');
    if (hit == null || lat == null || lon == null) {
      throw const GeocodeException('Adresse non trouvée : aucun résultat au Maroc pour cette recherche.');
    }
    return GeocodeResult(
      point: LatLng(lat, lon),
      label: (hit['display_name'] ?? q).toString(),
      type: hit['type']?.toString(),
    );
  }
}
