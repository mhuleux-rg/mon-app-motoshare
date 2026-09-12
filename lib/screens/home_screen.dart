import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/settings_service.dart';
import '../db/database_helper.dart';
import '../models/visite.dart';
import 'settings_screen.dart';
import 'visite_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Visite>> _futureVisites;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futureVisites = DatabaseHelper.instance.getVisites();
    });
  }

  Future<void> _creerVisite() async {
    final clientController = TextEditingController();
    final adresseController = TextEditingController();
    TypeInstallation type = TypeInstallation.photovoltaique;
    final nomTechnicienDefaut = await SettingsService.getNomDefautTechnicien();
    final technicienController = TextEditingController(text: nomTechnicienDefaut ?? '');

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nouvelle visite technique'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: clientController,
                      decoration: const InputDecoration(labelText: 'Client'),
                    ),
                    TextField(
                      controller: adresseController,
                      decoration: const InputDecoration(labelText: 'Adresse du site'),
                    ),
                    TextField(
                      controller: technicienController,
                      decoration: const InputDecoration(labelText: 'Technicien'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TypeInstallation>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Type d\'installation'),
                      items: const [
                        DropdownMenuItem(
                          value: TypeInstallation.photovoltaique,
                          child: Text('Photovoltaïque'),
                        ),
                        DropdownMenuItem(
                          value: TypeInstallation.batterie,
                          child: Text('Batterie / Stockage'),
                        ),
                        DropdownMenuItem(
                          value: TypeInstallation.mixte,
                          child: Text('PV + Batterie'),
                        ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() => type = value ?? TypeInstallation.photovoltaique);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirme != true) return;
    if (clientController.text.trim().isEmpty || adresseController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client et adresse sont obligatoires')),
        );
      }
      return;
    }

    final visite = Visite(
      id: const Uuid().v4(),
      client: clientController.text.trim(),
      adresse: adresseController.text.trim(),
      type: type,
      date: DateTime.now(),
      nomTechnicien: technicienController.text.trim().isEmpty ? null : technicienController.text.trim(),
    );

    await DatabaseHelper.instance.insertVisite(visite);
    _reload();

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisiteDetailScreen(visiteId: visite.id)),
      );
      _reload();
    }
  }

  IconData _iconePourType(TypeInstallation type) {
    switch (type) {
      case TypeInstallation.photovoltaique:
        return Icons.solar_power;
      case TypeInstallation.batterie:
        return Icons.battery_charging_full;
      case TypeInstallation.mixte:
        return Icons.electric_bolt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visites techniques PV & Batterie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Visite>>(
        future: _futureVisites,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final visites = snapshot.data!;
          if (visites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucune visite pour le moment.\nAppuyez sur + pour créer votre première visite.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: visites.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final visite = visites[index];
              return ListTile(
                leading: CircleAvatar(child: Icon(_iconePourType(visite.type))),
                title: Text(visite.client),
                subtitle: Text('${visite.adresse}\n${_dateFormat.format(visite.date)}'),
                isThreeLine: true,
                trailing: visite.cloturee
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VisiteDetailScreen(visiteId: visite.id)),
                  );
                  _reload();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creerVisite,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle visite'),
      ),
    );
  }
}
