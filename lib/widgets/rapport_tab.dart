import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/visite.dart';
import '../pdf/rapport_pdf_service.dart';
import '../services/backup_service.dart';

class RapportTab extends StatefulWidget {
  final Visite visite;

  const RapportTab({super.key, required this.visite});

  @override
  State<RapportTab> createState() => _RapportTabState();
}

class _RapportTabState extends State<RapportTab> {
  bool _generationPdf = false;
  bool _generationZip = false;
  String? _erreur;

  Future<void> _genererEtPartagerPdf() async {
    setState(() {
      _generationPdf = true;
      _erreur = null;
    });
    try {
      final fichier = await RapportPdfService.genererRapport(widget.visite);
      await Share.shareXFiles(
        [XFile(fichier.path)],
        subject: 'Rapport de visite - ${widget.visite.client}',
        text: 'Rapport de visite technique pour ${widget.visite.client}',
      );
    } catch (e) {
      setState(() => _erreur = 'Erreur lors de la génération du PDF : $e');
    } finally {
      setState(() => _generationPdf = false);
    }
  }

  Future<void> _exporterVisiteZip() async {
    setState(() {
      _generationZip = true;
      _erreur = null;
    });
    try {
      final fichier = await BackupService.exporterVisite(widget.visite);
      await Share.shareXFiles(
        [XFile(fichier.path)],
        subject: 'Export complet - ${widget.visite.client}',
        text: 'Export complet (fiche, checklist, photos, PDF) pour ${widget.visite.client}',
      );
    } catch (e) {
      setState(() => _erreur = "Erreur lors de l'export ZIP : $e");
    } finally {
      setState(() => _generationZip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Générez le rapport PDF de la visite, ou exportez tout le dossier (fiche, checklist, photos et PDF) en une archive ZIP partageable.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generationPdf ? null : _genererEtPartagerPdf,
              icon: _generationPdf
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Générer et partager le PDF'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _generationZip ? null : _exporterVisiteZip,
              icon: _generationZip
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_zip_outlined),
              label: const Text('Exporter le dossier complet (ZIP)'),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 16),
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
