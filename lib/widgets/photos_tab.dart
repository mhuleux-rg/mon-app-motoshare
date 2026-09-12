import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/photo_visite.dart';
import 'sketch_pad_screen.dart';

class PhotosTab extends StatefulWidget {
  final String visiteId;

  const PhotosTab({super.key, required this.visiteId});

  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab> {
  late Future<List<PhotoVisite>> _futurePhotos;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futurePhotos = DatabaseHelper.instance.getPhotos(widget.visiteId);
    });
  }

  Future<Directory> _dossierMedias() async {
    final dossierApp = await getApplicationDocumentsDirectory();
    final dossierVisite = Directory(p.join(dossierApp.path, 'photos', widget.visiteId));
    if (!await dossierVisite.exists()) {
      await dossierVisite.create(recursive: true);
    }
    return dossierVisite;
  }

  Future<void> _ajouterPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (xfile == null) return;

    final dossierVisite = await _dossierMedias();
    final nomFichier = '${const Uuid().v4()}${p.extension(xfile.path)}';
    final chemin = p.join(dossierVisite.path, nomFichier);
    await File(xfile.path).copy(chemin);

    final photo = PhotoVisite(
      id: const Uuid().v4(),
      visiteId: widget.visiteId,
      cheminFichier: chemin,
      dateAjout: DateTime.now(),
      type: TypeMedia.photo,
    );
    await DatabaseHelper.instance.insertPhoto(photo);
    _reload();
  }

  Future<void> _ajouterCroquis() async {
    final bytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => const SketchPadScreen()),
    );
    if (bytes == null) return;

    final dossierVisite = await _dossierMedias();
    final nomFichier = '${const Uuid().v4()}.png';
    final chemin = p.join(dossierVisite.path, nomFichier);
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

  Future<void> _choisirSource() async {
    final choix = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Ajouter au dossier de visite', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: const Text('Dessiner un croquis'),
              subtitle: const Text('Implantation, distances, accès...'),
              onTap: () => Navigator.pop(context, 2),
            ),
          ],
        ),
      ),
    );
    switch (choix) {
      case 0:
        await _ajouterPhoto(ImageSource.camera);
        break;
      case 1:
        await _ajouterPhoto(ImageSource.gallery);
        break;
      case 2:
        await _ajouterCroquis();
        break;
    }
  }

  Future<void> _editerLegende(PhotoVisite photo) async {
    final controller = TextEditingController(text: photo.legende);
    final resultat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(photo.type == TypeMedia.croquis ? 'Légende du croquis' : 'Légende de la photo'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ex : Coffret DUS façade nord'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (resultat != null) {
      await DatabaseHelper.instance.updatePhotoLegende(photo.id, resultat);
      _reload();
    }
  }

  Future<void> _supprimerPhoto(PhotoVisite photo) async {
    await DatabaseHelper.instance.deletePhoto(photo.id);
    final fichier = File(photo.cheminFichier);
    if (await fichier.exists()) {
      await fichier.delete();
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<PhotoVisite>>(
        future: _futurePhotos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucune photo ni croquis.\nAppuyez sur + pour en ajouter.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return GestureDetector(
                onTap: () => _editerLegende(photo),
                onLongPress: () => _supprimerPhoto(photo),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(photo.cheminFichier), fit: BoxFit.cover),
                            if (photo.type == TypeMedia.croquis)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.draw, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Croquis', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          photo.legende.isEmpty ? 'Ajouter une légende' : photo.legende,
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _choisirSource,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
