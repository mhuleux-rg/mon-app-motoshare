import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/visite.dart';
import '../widgets/checklist_tab.dart';
import '../widgets/photos_tab.dart';
import '../widgets/rapport_tab.dart';

class VisiteDetailScreen extends StatefulWidget {
  final String visiteId;

  const VisiteDetailScreen({super.key, required this.visiteId});

  @override
  State<VisiteDetailScreen> createState() => _VisiteDetailScreenState();
}

class _VisiteDetailScreenState extends State<VisiteDetailScreen> {
  Visite? _visite;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final visite = await DatabaseHelper.instance.getVisite(widget.visiteId);
    setState(() {
      _visite = visite;
      _chargement = false;
    });
  }

  Future<void> _sauvegarder() async {
    if (_visite == null) return;
    await DatabaseHelper.instance.updateVisite(_visite!);
  }

  Future<void> _capturerGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _visite!.latitude = position.latitude;
        _visite!.longitude = position.longitude;
      });
      await _sauvegarder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position GPS enregistrée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de récupérer la position : $e')),
        );
      }
    }
  }

  Future<void> _supprimerVisite() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette visite ?'),
        content: const Text('Cette action supprimera aussi les photos et la checklist associées.'),
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
    if (confirme == true) {
      await DatabaseHelper.instance.deleteVisite(widget.visiteId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_visite == null) {
      return const Scaffold(body: Center(child: Text('Visite introuvable')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_visite!.client),
          actions: [
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _supprimerVisite),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Infos'),
              Tab(icon: Icon(Icons.photo_camera_outlined), text: 'Photos'),
              Tab(icon: Icon(Icons.checklist), text: 'Checklist'),
              Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'Rapport'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InfosTab(
              visite: _visite!,
              onChange: () => setState(() {}),
              onSauvegarder: _sauvegarder,
              onCapturerGps: _capturerGps,
            ),
            PhotosTab(visiteId: _visite!.id),
            ChecklistTab(visite: _visite!),
            RapportTab(visite: _visite!),
          ],
        ),
      ),
    );
  }
}

class _InfosTab extends StatefulWidget {
  final Visite visite;
  final VoidCallback onChange;
  final Future<void> Function() onSauvegarder;
  final Future<void> Function() onCapturerGps;

  const _InfosTab({
    required this.visite,
    required this.onChange,
    required this.onSauvegarder,
    required this.onCapturerGps,
  });

  @override
  State<_InfosTab> createState() => _InfosTabState();
}

class _InfosTabState extends State<_InfosTab> {
  late TextEditingController _clientController;
  late TextEditingController _adresseController;
  late TextEditingController _technicienController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _clientController = TextEditingController(text: widget.visite.client);
    _adresseController = TextEditingController(text: widget.visite.adresse);
    _technicienController = TextEditingController(text: widget.visite.nomTechnicien ?? '');
    _notesController = TextEditingController(text: widget.visite.notesGenerales);
  }

  @override
  void dispose() {
    _clientController.dispose();
    _adresseController.dispose();
    _technicienController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visite = widget.visite;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _clientController,
            decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
            onChanged: (v) {
              visite.client = v;
              widget.onSauvegarder();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adresseController,
            decoration: const InputDecoration(labelText: 'Adresse du site', border: OutlineInputBorder()),
            maxLines: 2,
            onChanged: (v) {
              visite.adresse = v;
              widget.onSauvegarder();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _technicienController,
            decoration: const InputDecoration(labelText: 'Technicien', border: OutlineInputBorder()),
            onChanged: (v) {
              visite.nomTechnicien = v;
              widget.onSauvegarder();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TypeInstallation>(
            value: visite.type,
            decoration: const InputDecoration(labelText: "Type d'installation", border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: TypeInstallation.photovoltaique, child: Text('Photovoltaïque')),
              DropdownMenuItem(value: TypeInstallation.batterie, child: Text('Batterie / Stockage')),
              DropdownMenuItem(value: TypeInstallation.mixte, child: Text('PV + Batterie')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => visite.type = value);
              widget.onSauvegarder();
            },
          ),
          const SizedBox(height: 16),
          Text('Visite créée le : ${dateFormat.format(visite.date)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      visite.latitude != null
                          ? 'Position GPS : ${visite.latitude!.toStringAsFixed(5)}, ${visite.longitude!.toStringAsFixed(5)}'
                          : 'Aucune position GPS enregistrée',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await widget.onCapturerGps();
                      setState(() {});
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Capturer'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes générales de la visite',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 8,
            onChanged: (v) {
              visite.notesGenerales = v;
              widget.onSauvegarder();
            },
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Visite clôturée'),
            subtitle: const Text('Marque la visite comme terminée'),
            value: visite.cloturee,
            onChanged: (value) {
              setState(() => visite.cloturee = value);
              widget.onSauvegarder();
            },
          ),
        ],
      ),
    );
  }
}
