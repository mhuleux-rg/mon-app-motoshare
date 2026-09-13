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

  bool _estRenseigne(ChecklistItemReponse r) {
    switch (r.typeItem) {
      case 'case':
        return r.valeurCase == true;
      case 'nombre':
        return r.valeurNombre != null;
      default:
        return r.valeurTexte != null && r.valeurTexte!.isNotEmpty;
    }
  }

  (int, int) _progressionSection(ChecklistSectionDef section) {
    var renseignes = 0;
    for (final item in section.items) {
      final r = _reponses[item.id];
      if (r != null && _estRenseigne(r)) renseignes++;
    }
    return (renseignes, section.items.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        for (final template in _templates) ..._buildTemplate(template),
      ],
    );
  }

  List<Widget> _buildTemplate(ChecklistTemplate template) {
    final widgets = <Widget>[
      Card(
        margin: const EdgeInsets.only(bottom: 14),
        color: const Color(0xFFFFF6E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB2650A), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.type == 'pv' ? 'Checklist Photovoltaïque' : 'Checklist Batterie / Stockage',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(template.disclaimer, style: Theme.of(context).textTheme.bodySmall),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Textes et références à vérifier', style: TextStyle(fontSize: 13)),
                  children: template.referencesAVerifier
                      .map((ref) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('•  $ref', style: Theme.of(context).textTheme.bodySmall),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    for (final section in template.sections) {
      widgets.add(_buildSection(section));
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }

  Widget _buildSection(ChecklistSectionDef section) {
    final (renseignes, total) = _progressionSection(section);
    final complet = total > 0 && renseignes == total;

    final itemsMesure = section.items.where((i) => i.type != 'case').toList();
    final itemsCase = section.items.where((i) => i.type == 'case').toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(section.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: complet ? const Color(0xFF0E6E52).withValues(alpha: 0.12) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$renseignes/$total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: complet ? const Color(0xFF0E6E52) : Colors.grey.shade700,
              ),
            ),
          ),
          children: [
            if (itemsMesure.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MESURES ET CARACTÉRISTIQUES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in itemsMesure) _buildChampMesure(item, _reponses[item.id]!),
                      ],
                    ),
                  ],
                ),
              ),
            if (itemsCase.isNotEmpty) ...[
              if (itemsMesure.isNotEmpty) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Text(
                  'POINTS DE CONTRÔLE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                ),
              ),
              for (final item in itemsCase) _buildCaseAControler(item, _reponses[item.id]!),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaseAControler(ChecklistItemDef item, ChecklistItemReponse reponse) {
    return CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Text(item.label, style: const TextStyle(fontSize: 14)),
      subtitle: reponse.aVerifierSurSite
          ? const Text('À vérifier sur site', style: TextStyle(color: Color(0xFFB2650A), fontSize: 11))
          : null,
      value: reponse.valeurCase ?? false,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (value) {
        setState(() => reponse.valeurCase = value);
        _sauvegarderReponse(reponse);
      },
    );
  }

  Widget _buildChampMesure(ChecklistItemDef item, ChecklistItemReponse reponse) {
    final largeur = item.type == 'choix' || item.type == 'texte' ? 300.0 : 155.0;

    Widget champ;
    switch (item.type) {
      case 'nombre':
        champ = TextFormField(
          initialValue: reponse.valeurNombre?.toString() ?? '',
          decoration: InputDecoration(
            isDense: true,
            suffixText: item.unite,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            reponse.valeurNombre = double.tryParse(v.replaceAll(',', '.'));
            _sauvegarderReponse(reponse);
          },
        );
        break;
      case 'choix':
        champ = DropdownButtonFormField<String>(
          value: reponse.valeurTexte,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: (item.options ?? [])
              .map((option) => DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (value) {
            setState(() => reponse.valeurTexte = value);
            _sauvegarderReponse(reponse);
          },
        );
        break;
      default:
        champ = TextFormField(
          initialValue: reponse.valeurTexte ?? '',
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          onChanged: (v) {
            reponse.valeurTexte = v;
            _sauvegarderReponse(reponse);
          },
        );
    }

    return SizedBox(
      width: largeur,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ),
              if (reponse.aVerifierSurSite)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB2650A)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          champ,
        ],
      ),
    );
  }
}
