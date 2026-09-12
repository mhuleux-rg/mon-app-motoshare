import 'package:shared_preferences/shared_preferences.dart';

/// Permet de personnaliser les valeurs indicatives par défaut des checklists
/// réglementaires (distances, etc.) sans modifier le code de l'application.
/// Ces valeurs restent des valeurs de départ modifiables lors de chaque visite ;
/// elles ne remplacent pas une vérification réglementaire au cas par cas.
class SettingsService {
  static const _prefix = 'override_valeur_';
  static const _keyNomSociete = 'nom_societe';
  static const _keyNomDefautTechnicien = 'nom_defaut_technicien';

  static Future<double?> getValeurIndicative(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_prefix$itemId');
  }

  static Future<void> setValeurIndicative(String itemId, double? valeur) async {
    final prefs = await SharedPreferences.getInstance();
    if (valeur == null) {
      await prefs.remove('$_prefix$itemId');
    } else {
      await prefs.setDouble('$_prefix$itemId', valeur);
    }
  }

  static Future<String?> getNomSociete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNomSociete);
  }

  static Future<void> setNomSociete(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNomSociete, value);
  }

  static Future<String?> getNomDefautTechnicien() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNomDefautTechnicien);
  }

  static Future<void> setNomDefautTechnicien(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNomDefautTechnicien, value);
  }
}
