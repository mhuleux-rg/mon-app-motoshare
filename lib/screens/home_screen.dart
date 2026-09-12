import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/settings_service.dart';
import '../db/database_helper.dart';
import '../models/client.dart';
import '../models/visite.dart';
import 'clients_screen.dart';
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
  final _rechercheController = TextEditingController();
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futureVisites = DatabaseHelper.instance.getVisites(recherche: _recherche);
    });
  }

  Future<Client?> _choisirClientExistant() async {
    final clients = await DatabaseHelper.instance.getClients();
    if (clients.isEmpty) return null;
    return showDialog<Client>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir un client existant'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return ListTile(
                title: Text(client.nom),
                subtitle: Text(client.adresse, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, client),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ],
      ),
    );
  }

  Future<void> _creerVisite() async {
    String? clientIdSelectionne;
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final client = await _choisirClientExistant();
                          if (client != null) {
                            clientController.text = client.nom;
                            adresseController.text = client.adresse;
                            setStateDialog(() => clientIdSelectionne = client.id);
                          }
                        },
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: const Text('Choisir un client existant'),
                      ),
                    ),
                    TextField(
                      controller: clientController,
                      decoration: const InputDecoration(labelText: 'Client'),
                      onChanged: (_) => clientIdSelectionne = null,
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
      clientId: clientIdSelectionne,
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

  String _libellePourType(TypeInstallation type) {
    switch (type) {
      case TypeInstallation.photovoltaique:
        return 'Photovoltaïque';
      case TypeInstallation.batterie:
        return 'Batterie';
      case TypeInstallation.mixte:
        return 'PV + Batterie';
    }
  }

  Color _couleurPourType(BuildContext context, TypeInstallation type) {
    switch (type) {
      case TypeInstallation.photovoltaique:
        return const Color(0xFF0E6E52);
      case TypeInstallation.batterie:
        return const Color(0xFFB2650A);
      case TypeInstallation.mixte:
        return const Color(0xFF2B5FA6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visites PV & Batterie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Clients',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientsScreen()),
              );
              _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: TextField(
              controller: _rechercheController,
              decoration: InputDecoration(
                hintText: 'Rechercher client ou adresse...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rechercheController.clear();
                          _recherche = '';
                          _reload();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                _recherche = v;
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Visite>>(
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.solar_power_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aucune visite pour le moment',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Appuyez sur "Nouvelle visite" pour démarrer.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: visites.length,
            itemBuilder: (context, index) {
              final visite = visites[index];
              final couleurType = _couleurPourType(context, visite.type);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => VisiteDetailScreen(visiteId: visite.id)),
                      );
                      _reload();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: couleurType.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_iconePourType(visite.type), color: couleurType),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visite.client,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  visite.adresse,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: couleurType.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _libellePourType(visite.type),
                                        style: TextStyle(color: couleurType, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _dateFormat.format(visite.date),
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          visite.cloturee
                              ? const Icon(Icons.check_circle, color: Color(0xFF0E6E52))
                              : Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creerVisite,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle visite'),
      ),
    );
  }
}
