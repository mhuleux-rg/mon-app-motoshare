import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/photo_visite.dart';

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

  Future<void> _ajouterPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (xfile == null) return;

    final dossierApp = await getApplicationDocumentsDirectory();
    final dossierVisite = Directory(p.join(dossierApp.path, 'photos', widget.visiteId));
    if (!await dossierVisite.exists()) {
      await dossierVisite.create(recursive: true);
    }
    final nomFichier = '${const Uuid().v4()}${p.extension(xfile.path)}';
    final chemin = p.join(dossierVisite.path, nomFichier);
    await File(xfile.path).copy(chemin);

    final photo = PhotoVisite(
      id: const Uuid().v4(),
      visiteId: widget.visiteId,
      cheminFichier: chemin,
      dateAjout: DateTime.now(),
    );
    await DatabaseHelper.instance.insertPhoto(photo);
    _reload();
  }

  Future<void> _choisirSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _ajouterPhoto(source);
    }
  }

  Future<void> _editerLegende(PhotoVisite photo) async {
    final controller = TextEditingController(text: photo.legende);
    final resultat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Légende de la photo'),
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
            return const Center(child: Text('Aucune photo. Appuyez sur + pour en ajouter.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.file(File(photo.cheminFichier), fit: BoxFit.cover, width: double.infinity),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _choisirSource,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
