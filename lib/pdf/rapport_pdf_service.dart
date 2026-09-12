import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/checklist_repository.dart';
import '../data/checklist_template.dart';
import '../db/database_helper.dart';
import '../models/checklist_item_reponse.dart';
import '../models/photo_visite.dart';
import '../models/visite.dart';

class RapportPdfService {
  static Future<File> genererRapport(Visite visite) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final photos = await DatabaseHelper.instance.getPhotos(visite.id);
    final reponses = await DatabaseHelper.instance.getChecklistReponses(visite.id);
    final reponsesParItem = {for (final r in reponses) r.itemId: r};

    final templates = <ChecklistTemplate>[];
    if (visite.type == TypeInstallation.photovoltaique || visite.type == TypeInstallation.mixte) {
      templates.add(await ChecklistRepository.loadPv());
    }
    if (visite.type == TypeInstallation.batterie || visite.type == TypeInstallation.mixte) {
      templates.add(await ChecklistRepository.loadBatterie());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Rapport de visite technique',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          _sectionIdentification(visite, dateFormat),
          pw.SizedBox(height: 16),
          if (visite.notesGenerales.trim().isNotEmpty) ...[
            pw.Text('Notes générales', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(visite.notesGenerales),
            pw.SizedBox(height: 16),
          ],
          for (final template in templates) ..._sectionChecklist(template, reponsesParItem),
          pw.SizedBox(height: 16),
          if (photos.isNotEmpty) ...[
            pw.Text('Photos et croquis', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );

    for (final photo in photos) {
      final fichier = File(photo.cheminFichier);
      if (!await fichier.exists()) continue;
      final bytes = await fichier.readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Image(image, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 8),
              pw.Text(
                photo.type == TypeMedia.croquis ? 'Croquis' : 'Photo',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              if (photo.legende.isNotEmpty) pw.Text(photo.legende, style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    final dossier = await getApplicationDocumentsDirectory();
    final dossierRapports = Directory(p.join(dossier.path, 'rapports'));
    if (!await dossierRapports.exists()) {
      await dossierRapports.create(recursive: true);
    }
    final nomFichier = 'rapport_${visite.client.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final chemin = p.join(dossierRapports.path, nomFichier);
    final fichier = File(chemin);
    await fichier.writeAsBytes(await doc.save());
    return fichier;
  }

  static pw.Widget _sectionIdentification(Visite visite, DateFormat dateFormat) {
    String typeLabel;
    switch (visite.type) {
      case TypeInstallation.photovoltaique:
        typeLabel = 'Photovoltaïque';
        break;
      case TypeInstallation.batterie:
        typeLabel = 'Batterie / Stockage';
        break;
      case TypeInstallation.mixte:
        typeLabel = 'Photovoltaïque + Batterie';
        break;
    }

    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(2)},
      children: [
        _ligneTable('Client', visite.client),
        _ligneTable('Adresse', visite.adresse),
        _ligneTable('Type d\'installation', typeLabel),
        _ligneTable('Date de visite', dateFormat.format(visite.date)),
        if (visite.nomTechnicien != null) _ligneTable('Technicien', visite.nomTechnicien!),
        if (visite.latitude != null)
          _ligneTable('Position GPS', '${visite.latitude!.toStringAsFixed(5)}, ${visite.longitude!.toStringAsFixed(5)}'),
      ],
    );
  }

  static pw.TableRow _ligneTable(String label, String valeur) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text(valeur),
        ),
      ],
    );
  }

  static List<pw.Widget> _sectionChecklist(
    ChecklistTemplate template,
    Map<String, ChecklistItemReponse> reponsesParItem,
  ) {
    final widgets = <pw.Widget>[
      pw.Text(
        template.type == 'pv' ? 'Checklist réglementaire - Photovoltaïque' : 'Checklist réglementaire - Batterie',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        template.disclaimer,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
    ];

    for (final section in template.sections) {
      widgets.add(pw.Text(section.titre, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));
      for (final item in section.items) {
        final reponse = reponsesParItem[item.id];
        if (reponse == null) continue;
        widgets.add(_ligneChecklist(reponse));
      }
      widgets.add(pw.SizedBox(height: 6));
    }

    return widgets;
  }

  static pw.Widget _ligneChecklist(ChecklistItemReponse reponse) {
    String valeurAffichee;
    switch (reponse.typeItem) {
      case 'case':
        valeurAffichee = (reponse.valeurCase ?? false) ? 'Oui' : 'Non';
        break;
      case 'nombre':
        valeurAffichee = reponse.valeurNombre != null
            ? '${reponse.valeurNombre} ${reponse.unite ?? ''}'
            : 'Non renseigné';
        break;
      default:
        valeurAffichee = (reponse.valeurTexte == null || reponse.valeurTexte!.isEmpty)
            ? 'Non renseigné'
            : reponse.valeurTexte!;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(flex: 3, child: pw.Text(reponse.label, style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              valeurAffichee + (reponse.aVerifierSurSite ? '  (à vérifier)' : ''),
              style: pw.TextStyle(
                fontSize: 10,
                color: reponse.aVerifierSurSite ? PdfColors.orange800 : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
