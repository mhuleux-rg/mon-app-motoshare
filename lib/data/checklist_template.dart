class ChecklistItemDef {
  final String id;
  final String label;
  final String type; // "case" | "nombre" | "texte" | "choix"
  final String? unite;
  final List<String>? options;
  final double? valeurIndicative;
  final bool aVerifier;

  ChecklistItemDef({
    required this.id,
    required this.label,
    required this.type,
    this.unite,
    this.options,
    this.valeurIndicative,
    this.aVerifier = false,
  });

  factory ChecklistItemDef.fromJson(Map<String, dynamic> json) {
    return ChecklistItemDef(
      id: json['id'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      unite: json['unite'] as String?,
      options: (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      valeurIndicative: (json['valeur_indicative'] as num?)?.toDouble(),
      aVerifier: json['a_verifier'] as bool? ?? false,
    );
  }
}

class ChecklistSectionDef {
  final String id;
  final String titre;
  final List<ChecklistItemDef> items;

  ChecklistSectionDef({required this.id, required this.titre, required this.items});

  factory ChecklistSectionDef.fromJson(Map<String, dynamic> json) {
    return ChecklistSectionDef(
      id: json['id'] as String,
      titre: json['titre'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => ChecklistItemDef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChecklistTemplate {
  final String type;
  final String version;
  final String disclaimer;
  final List<String> referencesAVerifier;
  final List<ChecklistSectionDef> sections;

  ChecklistTemplate({
    required this.type,
    required this.version,
    required this.disclaimer,
    required this.referencesAVerifier,
    required this.sections,
  });

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplate(
      type: json['type'] as String,
      version: json['version'] as String,
      disclaimer: json['disclaimer'] as String,
      referencesAVerifier: (json['references_a_verifier'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      sections: (json['sections'] as List<dynamic>)
          .map((e) => ChecklistSectionDef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
