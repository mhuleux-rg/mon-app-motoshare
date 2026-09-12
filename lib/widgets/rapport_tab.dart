import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/visite.dart';
import '../pdf/rapport_pdf_service.dart';

class RapportTab extends StatefulWidget {
  final Visite visite;

  const RapportTab({super.key, required this.visite});

  @override
  State<RapportTab> createState() => _RapportTabState();
}

class _RapportTabState extends State<RapportTab> {
  bool _generation = false;
  File? _dernierRapport;
  String? _erreur;

  Future<void> _genererEtPartager() async {
    setState(() {
      _generation = true;
      _erreur = null;
    });
    try {
      final fichier = await RapportPdfService.genererRapport(widget.visite);
      setState(() => _dernierRapport = fichier);
      await Share.shareXFiles(
        [XFile(fichier.path)],
        subject: 'Rapport de visite - ${widget.visite.client}',
        text: 'Rapport de visite technique pour ${widget.visite.client}',
      );
    } catch (e) {
      setState(() => _erreur = 'Erreur lors de la génération du PDF : $e');
    } finally {
      setState(() => _generation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Générez le rapport PDF complet de la visite : informations, checklist réglementaire, notes et photos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_generation)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _genererEtPartager,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Générer et partager le PDF'),
              ),
            if (_erreur != null) ...[
              const SizedBox(height: 16),
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ],
            if (_dernierRapport != null) ...[
              const SizedBox(height: 16),
              Text('Dernier rapport : ${_dernierRapport!.path}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
