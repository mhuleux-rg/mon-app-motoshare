enum TypeInstallation { photovoltaique, batterie, mixte }

TypeInstallation typeInstallationFromString(String value) {
  return TypeInstallation.values.firstWhere(
    (e) => e.name == value,
    orElse: () => TypeInstallation.photovoltaique,
  );
}

class Visite {
  final String id;
  String? clientId;
  String client;
  String adresse;
  double? latitude;
  double? longitude;
  TypeInstallation type;
  DateTime date;
  String? nomTechnicien;
  String notesGenerales;
  bool cloturee;

  Visite({
    required this.id,
    this.clientId,
    required this.client,
    required this.adresse,
    this.latitude,
    this.longitude,
    required this.type,
    required this.date,
    this.nomTechnicien,
    this.notesGenerales = '',
    this.cloturee = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'client': client,
      'adresse': adresse,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'date': date.toIso8601String(),
      'nomTechnicien': nomTechnicien,
      'notesGenerales': notesGenerales,
      'cloturee': cloturee ? 1 : 0,
    };
  }

  factory Visite.fromMap(Map<String, dynamic> map) {
    return Visite(
      id: map['id'] as String,
      clientId: map['clientId'] as String?,
      client: map['client'] as String,
      adresse: map['adresse'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      type: typeInstallationFromString(map['type'] as String),
      date: DateTime.parse(map['date'] as String),
      nomTechnicien: map['nomTechnicien'] as String?,
      notesGenerales: map['notesGenerales'] as String? ?? '',
      cloturee: (map['cloturee'] as int? ?? 0) == 1,
    );
  }
}
