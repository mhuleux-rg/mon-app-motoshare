import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/photo_visite.dart';
import 'sketch_pad_screen.dart';

/// Onglet dédié aux croquis à main levée (implantation, distances, accès).
/// Séparé des photos pour être immédiatement visible et accessible.
class CroquisTab extends StatefulWidget {
  final String visiteId;

  const CroquisTab({super.key, required this.visiteId});

  @override
  State<CroquisTab> createState() => _CroquisTabState();
}

class _CroquisTabState extends State<CroquisTab> {
  late Future<List<PhotoVisite>> _futureCroquis;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futureCroquis = _chargerCroquis();
    });
  }

  Future<List<PhotoVisite>> _chargerCroquis() async {
    final tous = await DatabaseHelper.instance.getPhotos(widget.visiteId);
    return tous.where((m) => m.type == TypeMedia.croquis).toList();
  }

  Future<void> _nouveauCroquis() async {
    final bytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => const SketchPadScreen()),
    );
    if (bytes == null) return;

    final dossierApp = await getApplicationDocumentsDirectory();
    final dossierVisite = Directory(p.join(dossierApp.path, 'photos', widget.visiteId));
    if (!await dossierVisite.exists()) {
      await dossierVisite.create(recursive: true);
    }
    final chemin = p.join(dossierVisite.path, '${const Uuid().v4()}.png');
    await File(chemin).writeAsBytes(bytes);

    final croquis = PhotoVisite(
      id: const Uuid().v4(),
      visiteId: widget.visiteId,
      cheminFichier: chemin,
      legende: 'Croquis du site',
      dateAjout: DateTime.now(),
      type: TypeMedia.croquis,
    );
    await DatabaseHelper.instance.insertPhoto(croquis);
    _reload();
  }

  Future<void> _editerLegende(PhotoVisite croquis) async {
    final controller = TextEditingController(text: croquis.legende);
    final resultat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Légende du croquis'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ex : Implantation conteneur + distances'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (resultat != null) {
      await DatabaseHelper.instance.updatePhotoLegende(croquis.id, resultat);
      _reload();
    }
  }

  Future<void> _supprimer(PhotoVisite croquis) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce croquis ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await DatabaseHelper.instance.deletePhoto(croquis.id);
    final fichier = File(croquis.cheminFichier);
    if (await fichier.exists()) await fichier.delete();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<PhotoVisite>>(
        future: _futureCroquis,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final croquis = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.draw_outlined, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Croquis du site', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              'Implantation, distances, accès...',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (croquis.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.draw_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            "Aucun croquis pour l'instant.\nDessinez l'implantation, les distances\nou les accès du site.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _nouveauCroquis,
                            icon: const Icon(Icons.add),
                            label: const Text('Nouveau croquis'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = croquis[index];
                        return GestureDetector(
                          onTap: () => _editerLegende(item),
                          onLongPress: () => _supprimer(item),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    color: Colors.white,
                                    child: Image.file(File(item.cheminFichier), fit: BoxFit.contain),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Text(
                                    item.legende.isEmpty ? 'Sans légende' : item.legende,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: croquis.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouveauCroquis,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau croquis'),
      ),
    );
  }
}
