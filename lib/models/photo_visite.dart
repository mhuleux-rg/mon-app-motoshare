class PhotoVisite {
  final String id;
  final String visiteId;
  String cheminFichier;
  String legende;
  DateTime dateAjout;
  double? latitude;
  double? longitude;

  PhotoVisite({
    required this.id,
    required this.visiteId,
    required this.cheminFichier,
    this.legende = '',
    required this.dateAjout,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visiteId': visiteId,
      'cheminFichier': cheminFichier,
      'legende': legende,
      'dateAjout': dateAjout.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory PhotoVisite.fromMap(Map<String, dynamic> map) {
    return PhotoVisite(
      id: map['id'] as String,
      visiteId: map['visiteId'] as String,
      cheminFichier: map['cheminFichier'] as String,
      legende: map['legende'] as String? ?? '',
      dateAjout: DateTime.parse(map['dateAjout'] as String),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
    );
  }
}
