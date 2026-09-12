import 'package:flutter/material.dart';

import '../data/checklist_repository.dart';
import '../data/checklist_template.dart';
import '../data/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _societeController = TextEditingController();
  final _technicienController = TextEditingController();
  List<ChecklistTemplate> _templates = [];
  final Map<String, TextEditingController> _controllersDistances = {};
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final societe = await SettingsService.getNomSociete();
    final technicien = await SettingsService.getNomDefautTechnicien();
    _societeController.text = societe ?? '';
    _technicienController.text = technicien ?? '';

    final pv = await ChecklistRepository.loadPv();
    final batterie = await ChecklistRepository.loadBatterie();
    _templates = [pv, batterie];

    for (final template in _templates) {
      for (final section in template.sections) {
        for (final item in section.items) {
          if (item.type == 'nombre') {
            final override = await SettingsService.getValeurIndicative(item.id);
            final valeur = override ?? item.valeurIndicative;
            _controllersDistances[item.id] = TextEditingController(text: valeur?.toString() ?? '');
          }
        }
      }
    }

    setState(() => _chargement = false);
  }

  @override
  void dispose() {
    _societeController.dispose();
    _technicienController.dispose();
    for (final c in _controllersDistances.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Informations générales', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _societeController,
                  decoration: const InputDecoration(labelText: 'Nom de la société', border: OutlineInputBorder()),
                  onChanged: (v) => SettingsService.setNomSociete(v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _technicienController,
                  decoration: const InputDecoration(labelText: 'Technicien par défaut', border: OutlineInputBorder()),
                  onChanged: (v) => SettingsService.setNomDefautTechnicien(v),
                ),
                const SizedBox(height: 24),
                Card(
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "Les valeurs ci-dessous ne sont que des valeurs de départ pour préremplir vos checklists. "
                      "Elles ne dispensent pas de vérifier la réglementation applicable (SDIS local, DTU, UTE C15-712, "
                      "textes ICPE) pour chaque visite.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final template in _templates) ..._buildTemplateSettings(template),
              ],
            ),
    );
  }

  List<Widget> _buildTemplateSettings(ChecklistTemplate template) {
    final widgets = <Widget>[
      Text(
        template.type == 'pv' ? 'Valeurs indicatives - Photovoltaïque' : 'Valeurs indicatives - Batterie',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
    ];

    for (final section in template.sections) {
      for (final item in section.items) {
        if (item.type != 'nombre') continue;
        final controller = _controllersDistances[item.id]!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: item.label,
                suffixText: item.unite,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                final valeur = double.tryParse(v.replaceAll(',', '.'));
                SettingsService.setValeurIndicative(item.id, valeur);
              },
            ),
          ),
        );
      }
    }
    widgets.add(const SizedBox(height: 16));
    return widgets;
  }
}
