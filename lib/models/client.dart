class Client {
  final String id;
  String nom;
  String adresse;
  double? latitude;
  double? longitude;
  String? telephone;
  String? email;
  String notes;
  DateTime dateCreation;

  Client({
    required this.id,
    required this.nom,
    required this.adresse,
    this.latitude,
    this.longitude,
    this.telephone,
    this.email,
    this.notes = '',
    required this.dateCreation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'adresse': adresse,
      'latitude': latitude,
      'longitude': longitude,
      'telephone': telephone,
      'email': email,
      'notes': notes,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      nom: map['nom'] as String,
      adresse: map['adresse'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String? ?? '',
      dateCreation: DateTime.parse(map['dateCreation'] as String),
    );
  }
}
