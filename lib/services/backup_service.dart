import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/visite.dart';
import '../pdf/rapport_pdf_service.dart';

/// Export des données de visite (sauvegarde locale / partage) au format ZIP.
class BackupService {
  static Future<File> exporterVisite(Visite visite) async {
    final photos = await DatabaseHelper.instance.getPhotos(visite.id);
    final reponses = await DatabaseHelper.instance.getChecklistReponses(visite.id);

    final fiche = {
      'client': visite.client,
      'adresse': visite.adresse,
      'type': visite.type.name,
      'date': visite.date.toIso8601String(),
      'technicien': visite.nomTechnicien,
      'notesGenerales': visite.notesGenerales,
      'latitude': visite.latitude,
      'longitude': visite.longitude,
      'checklist': reponses
          .map((r) => {
                'section': r.sectionId,
                'label': r.label,
                'type': r.typeItem,
                'valeurTexte': r.valeurTexte,
                'valeurNombre': r.valeurNombre,
                'valeurCase': r.valeurCase,
                'unite': r.unite,
                'aVerifierSurSite': r.aVerifierSurSite,
                'commentaire': r.commentaire,
              })
          .toList(),
    };

    final archive = Archive();
    final ficheJson = const JsonEncoder.withIndent('  ').convert(fiche);
    archive.addFile(ArchiveFile('fiche_visite.json', ficheJson.length, utf8.encode(ficheJson)));

    for (final photo in photos) {
      final fichier = File(photo.cheminFichier);
      if (await fichier.exists()) {
        final bytes = await fichier.readAsBytes();
        archive.addFile(ArchiveFile('photos/${p.basename(photo.cheminFichier)}', bytes.length, bytes));
      }
    }

    try {
      final rapportPdf = await RapportPdfService.genererRapport(visite);
      final bytesPdf = await rapportPdf.readAsBytes();
      archive.addFile(ArchiveFile('rapport.pdf', bytesPdf.length, bytesPdf));
    } catch (_) {
      // Le PDF n'est pas bloquant pour l'export : la fiche JSON et les photos suffisent.
    }

    return _ecrireArchive(archive, 'visite_${_slug(visite.client)}');
  }

  static Future<File> exporterSauvegardeComplete() async {
    final visites = await DatabaseHelper.instance.getVisites();
    final clients = await DatabaseHelper.instance.getClients();
    final archive = Archive();

    final donnees = {
      'exporteLe': DateTime.now().toIso8601String(),
      'clients': clients.map((c) => c.toMap()).toList(),
      'visites': <Map<String, dynamic>>[],
    };

    for (final visite in visites) {
      final reponses = await DatabaseHelper.instance.getChecklistReponses(visite.id);
      final photos = await DatabaseHelper.instance.getPhotos(visite.id);

      (donnees['visites'] as List).add({
        ...visite.toMap(),
        'checklist': reponses.map((r) => r.toMap()).toList(),
        'photos': photos.map((ph) => ph.legende).toList(),
      });

      for (final photo in photos) {
        final fichier = File(photo.cheminFichier);
        if (await fichier.exists()) {
          final bytes = await fichier.readAsBytes();
          archive.addFile(
            ArchiveFile('photos/${visite.id}/${p.basename(photo.cheminFichier)}', bytes.length, bytes),
          );
        }
      }
    }

    final donneesJson = const JsonEncoder.withIndent('  ').convert(donnees);
    archive.addFile(ArchiveFile('sauvegarde.json', donneesJson.length, utf8.encode(donneesJson)));

    return _ecrireArchive(archive, 'sauvegarde_complete');
  }

  static Future<File> _ecrireArchive(Archive archive, String prefixe) async {
    final dossierApp = await getApplicationDocumentsDirectory();
    final dossierExports = Directory(p.join(dossierApp.path, 'exports'));
    if (!await dossierExports.exists()) {
      await dossierExports.create(recursive: true);
    }
    final horodatage = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final chemin = p.join(dossierExports.path, '${prefixe}_$horodatage.zip');

    final donneesZip = ZipEncoder().encode(archive) ?? <int>[];
    final fichier = File(chemin);
    await fichier.writeAsBytes(donneesZip);
    return fichier;
  }

  static String _slug(String valeur) {
    return valeur.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  }
}
