import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/checklist_repository.dart';
import '../data/checklist_template.dart';
import '../data/settings_service.dart';
import '../db/database_helper.dart';
import '../models/checklist_item_reponse.dart';
import '../models/visite.dart';

class ChecklistTab extends StatefulWidget {
  final Visite visite;

  const ChecklistTab({super.key, required this.visite});

  @override
  State<ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<ChecklistTab> {
  List<ChecklistTemplate> _templates = [];
  Map<String, ChecklistItemReponse> _reponses = {}; // clé = itemId
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final templates = <ChecklistTemplate>[];
    if (widget.visite.type == TypeInstallation.photovoltaique || widget.visite.type == TypeInstallation.mixte) {
      templates.add(await ChecklistRepository.loadPv());
    }
    if (widget.visite.type == TypeInstallation.batterie || widget.visite.type == TypeInstallation.mixte) {
      templates.add(await ChecklistRepository.loadBatterie());
    }

    final reponsesExistantes = await DatabaseHelper.instance.getChecklistReponses(widget.visite.id);
    final map = {for (final r in reponsesExistantes) r.itemId: r};

    // Crée les réponses manquantes avec valeurs indicatives (ou surcharge utilisateur)
    for (final template in templates) {
      for (final section in template.sections) {
        for (final item in section.items) {
          if (!map.containsKey(item.id)) {
            double? valeurInitiale = item.valeurIndicative;
            final override = await SettingsService.getValeurIndicative(item.id);
            if (override != null) valeurInitiale = override;

            final reponse = ChecklistItemReponse(
              id: const Uuid().v4(),
              visiteId: widget.visite.id,
              sectionId: section.id,
              itemId: item.id,
              label: item.label,
              typeItem: item.type,
              unite: item.unite,
              valeurNombre: item.type == 'nombre' ? valeurInitiale : null,
              aVerifierSurSite: item.aVerifier,
            );
            map[item.id] = reponse;
          }
        }
      }
    }

    setState(() {
      _templates = templates;
      _reponses = map;
      _chargement = false;
    });
  }

  Future<void> _sauvegarderReponse(ChecklistItemReponse reponse) async {
    await DatabaseHelper.instance.upsertChecklistReponse(reponse);
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final template in _templates) ..._buildTemplate(template),
      ],
    );
  }

  List<Widget> _buildTemplate(ChecklistTemplate template) {
    final widgets = <Widget>[];

    widgets.add(
      Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    template.type == 'pv' ? 'Checklist Photovoltaïque' : 'Checklist Batterie / Stockage',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(template.disclaimer, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Textes/références à vérifier', style: TextStyle(fontSize: 13)),
                children: template.referencesAVerifier
                    .map((ref) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $ref', style: Theme.of(context).textTheme.bodySmall),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );

    for (final section in template.sections) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(Text(section.titre, style: Theme.of(context).textTheme.titleMedium));
      for (final item in section.items) {
        final reponse = _reponses[item.id]!;
        widgets.add(_buildItem(item, reponse));
      }
    }

    return widgets;
  }

  Widget _buildItem(ChecklistItemDef item, ChecklistItemReponse reponse) {
    switch (item.type) {
      case 'case':
        return CheckboxListTile(
          title: Text(item.label),
          subtitle: reponse.aVerifierSurSite ? const Text('À vérifier sur site', style: TextStyle(color: Colors.orange)) : null,
          value: reponse.valeurCase ?? false,
          onChanged: (value) {
            setState(() => reponse.valeurCase = value);
            _sauvegarderReponse(reponse);
          },
        );
      case 'nombre':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: reponse.valeurNombre?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: item.label,
                    suffixText: item.unite,
                    helperText: reponse.aVerifierSurSite ? 'Valeur indicative à vérifier sur site' : null,
                    helperStyle: const TextStyle(color: Colors.orange),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    reponse.valeurNombre = double.tryParse(v.replaceAll(',', '.'));
                    _sauvegarderReponse(reponse);
                  },
                ),
              ),
            ],
          ),
        );
      case 'choix':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<String>(
            value: reponse.valeurTexte,
            decoration: InputDecoration(labelText: item.label),
            items: (item.options ?? [])
                .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                .toList(),
            onChanged: (value) {
              setState(() => reponse.valeurTexte = value);
              _sauvegarderReponse(reponse);
            },
          ),
        );
      case 'texte':
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            initialValue: reponse.valeurTexte ?? '',
            decoration: InputDecoration(
              labelText: item.label,
              helperText: reponse.aVerifierSurSite ? 'À vérifier sur site' : null,
              helperStyle: const TextStyle(color: Colors.orange),
            ),
            onChanged: (v) {
              reponse.valeurTexte = v;
              _sauvegarderReponse(reponse);
            },
          ),
        );
    }
  }
}
