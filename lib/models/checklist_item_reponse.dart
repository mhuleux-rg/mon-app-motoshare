/// Réponse enregistrée pour un item de checklist réglementaire, associée à une visite.
class ChecklistItemReponse {
  final String id;
  final String visiteId;
  final String sectionId;
  final String itemId;
  final String label;
  final String typeItem; // "case" | "nombre" | "texte" | "choix"
  String? valeurTexte;
  double? valeurNombre;
  bool? valeurCase;
  String? unite;
  bool aVerifierSurSite;
  String commentaire;

  ChecklistItemReponse({
    required this.id,
    required this.visiteId,
    required this.sectionId,
    required this.itemId,
    required this.label,
    required this.typeItem,
    this.valeurTexte,
    this.valeurNombre,
    this.valeurCase,
    this.unite,
    this.aVerifierSurSite = false,
    this.commentaire = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visiteId': visiteId,
      'sectionId': sectionId,
      'itemId': itemId,
      'label': label,
      'typeItem': typeItem,
      'valeurTexte': valeurTexte,
      'valeurNombre': valeurNombre,
      'valeurCase': valeurCase == null ? null : (valeurCase! ? 1 : 0),
      'unite': unite,
      'aVerifierSurSite': aVerifierSurSite ? 1 : 0,
      'commentaire': commentaire,
    };
  }

  factory ChecklistItemReponse.fromMap(Map<String, dynamic> map) {
    return ChecklistItemReponse(
      id: map['id'] as String,
      visiteId: map['visiteId'] as String,
      sectionId: map['sectionId'] as String,
      itemId: map['itemId'] as String,
      label: map['label'] as String,
      typeItem: map['typeItem'] as String,
      valeurTexte: map['valeurTexte'] as String?,
      valeurNombre: map['valeurNombre'] as double?,
      valeurCase: map['valeurCase'] == null ? null : (map['valeurCase'] as int) == 1,
      unite: map['unite'] as String?,
      aVerifierSurSite: (map['aVerifierSurSite'] as int? ?? 0) == 1,
      commentaire: map['commentaire'] as String? ?? '',
    );
  }
}
