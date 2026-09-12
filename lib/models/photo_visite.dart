enum TypeMedia { photo, croquis }

TypeMedia typeMediaFromString(String? value) {
  return TypeMedia.values.firstWhere(
    (e) => e.name == value,
    orElse: () => TypeMedia.photo,
  );
}

class PhotoVisite {
  final String id;
  final String visiteId;
  String cheminFichier;
  String legende;
  DateTime dateAjout;
  double? latitude;
  double? longitude;
  TypeMedia type;

  PhotoVisite({
    required this.id,
    required this.visiteId,
    required this.cheminFichier,
    this.legende = '',
    required this.dateAjout,
    this.latitude,
    this.longitude,
    this.type = TypeMedia.photo,
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
      'type': type.name,
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
      type: typeMediaFromString(map['type'] as String?),
    );
  }
}
