import 'dart:async';

import 'package:flutter/material.dart';

import '../services/geocoding_service.dart';

/// Champ d'adresse avec suggestions (Nominatim/OpenStreetMap). Sélectionner
/// une suggestion renseigne directement les coordonnées GPS correspondantes
/// (géolocalisation immédiate, sans étape supplémentaire).
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final void Function(SuggestionAdresse suggestion)? onAdresseSelectionnee;

  /// Appelé à chaque frappe (texte libre, sans sélection de suggestion) :
  /// utile pour sauvegarder la saisie même si l'utilisateur ne choisit
  /// aucune suggestion (dans ce cas, aucune coordonnée n'est renseignée).
  final void Function(String texte)? onTexteChange;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.labelText = 'Adresse',
    this.onAdresseSelectionnee,
    this.onTexteChange,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  Timer? _debounce;
  List<SuggestionAdresse> _suggestions = [];
  bool _recherche = false;

  void _onChanged(String valeur) {
    widget.onTexteChange?.call(valeur);
    _debounce?.cancel();
    if (valeur.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _recherche = false;
      });
      return;
    }
    setState(() => _recherche = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final resultats = await GeocodingService.rechercherAdresses(valeur);
      if (!mounted) return;
      setState(() {
        _suggestions = resultats;
        _recherche = false;
      });
    });
  }

  void _selectionner(SuggestionAdresse suggestion) {
    widget.controller.text = suggestion.libelle;
    setState(() => _suggestions = []);
    widget.onAdresseSelectionnee?.call(suggestion);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            suffixIcon: _recherche
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.location_on_outlined),
          ),
          onChanged: _onChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 18),
                  title: Text(suggestion.libelle, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _selectionner(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
