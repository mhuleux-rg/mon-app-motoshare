import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/client.dart';
import '../models/visite.dart';
import 'visite_detail_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Client? _client;
  List<Visite> _visites = [];
  bool _chargement = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final client = await DatabaseHelper.instance.getClient(widget.clientId);
    final visites = await DatabaseHelper.instance.getVisitesParClient(widget.clientId);
    setState(() {
      _client = client;
      _visites = visites;
      _chargement = false;
    });
  }

  Future<void> _nouvelleVisitePourClient() async {
    final client = _client;
    if (client == null) return;

    TypeInstallation type = TypeInstallation.photovoltaique;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nouvelle visite pour ce client'),
              content: DropdownButtonFormField<TypeInstallation>(
                value: type,
                decoration: const InputDecoration(labelText: "Type d'installation"),
                items: const [
                  DropdownMenuItem(value: TypeInstallation.photovoltaique, child: Text('Photovoltaïque')),
                  DropdownMenuItem(value: TypeInstallation.batterie, child: Text('Batterie / Stockage')),
                  DropdownMenuItem(value: TypeInstallation.mixte, child: Text('PV + Batterie')),
                ],
                onChanged: (value) => setStateDialog(() => type = value ?? TypeInstallation.photovoltaique),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
              ],
            );
          },
        );
      },
    );

    if (confirme != true) return;

    final visite = Visite(
      id: const Uuid().v4(),
      clientId: client.id,
      client: client.nom,
      adresse: client.adresse,
      type: type,
      date: DateTime.now(),
    );
    await DatabaseHelper.instance.insertVisite(visite);

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisiteDetailScreen(visiteId: visite.id)),
      );
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final client = _client;
    if (client == null) {
      return const Scaffold(body: Center(child: Text('Client introuvable')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(client.nom)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ligneInfo(Icons.location_on_outlined, client.adresse),
                  if (client.telephone != null) _ligneInfo(Icons.phone_outlined, client.telephone!),
                  if (client.email != null) _ligneInfo(Icons.email_outlined, client.email!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historique des visites (${_visites.length})', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: _nouvelleVisitePourClient,
                icon: const Icon(Icons.add),
                label: const Text('Visite'),
              ),
            ],
          ),
          if (_visites.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Aucune visite enregistrée pour ce client.', style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            for (final visite in _visites)
              Card(
                margin: const EdgeInsets.only(top: 10),
                child: ListTile(
                  leading: Icon(
                    visite.cloturee ? Icons.check_circle : Icons.pending_outlined,
                    color: visite.cloturee ? const Color(0xFF0E6E52) : Colors.grey,
                  ),
                  title: Text(_dateFormat.format(visite.date)),
                  subtitle: Text(visite.notesGenerales.isEmpty ? 'Aucune note' : visite.notesGenerales, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VisiteDetailScreen(visiteId: visite.id)),
                    );
                    _charger();
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(texte)),
        ],
      ),
    );
  }
}
