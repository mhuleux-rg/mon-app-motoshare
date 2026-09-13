import 'dart:convert';

import 'package:http/http.dart' as http;

class SuggestionAdresse {
  final String libelle;
  final double latitude;
  final double longitude;

  SuggestionAdresse({required this.libelle, required this.latitude, required this.longitude});
}

/// Recherche d'adresses via Nominatim (OpenStreetMap) : service public et
/// gratuit, sans clé API, mais sans garantie de disponibilité ni de SLA.
/// Respecte la politique d'usage (User-Agent identifié, requêtes limitées).
class GeocodingService {
  static Future<List<SuggestionAdresse>> rechercherAdresses(String requete) async {
    final motif = requete.trim();
    if (motif.length < 3) return [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': motif,
      'format': 'json',
      'addressdetails': '0',
      'limit': '5',
    });

    try {
      final reponse = await http
          .get(uri, headers: {'User-Agent': 'VisitePvBatterieApp/1.0 (usage interne)'})
          .timeout(const Duration(seconds: 6));
      if (reponse.statusCode != 200) return [];

      final data = jsonDecode(reponse.body) as List<dynamic>;
      return data
          .map((e) {
            final map = e as Map<String, dynamic>;
            final lat = double.tryParse(map['lat'] as String? ?? '');
            final lon = double.tryParse(map['lon'] as String? ?? '');
            if (lat == null || lon == null) return null;
            return SuggestionAdresse(
              libelle: map['display_name'] as String? ?? motif,
              latitude: lat,
              longitude: lon,
            );
          })
          .whereType<SuggestionAdresse>()
          .toList();
    } catch (_) {
      // Pas de connexion, service indisponible, etc. : on renvoie simplement
      // aucune suggestion plutôt que de bloquer la saisie manuelle.
      return [];
    }
  }
}
