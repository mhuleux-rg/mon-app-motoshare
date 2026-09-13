import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../models/client.dart';
import '../widgets/address_autocomplete_field.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late Future<List<Client>> _futureClients;
  final _rechercheController = TextEditingController();
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futureClients = DatabaseHelper.instance.getClients();
    });
  }

  Future<void> _creerOuEditerClient({Client? client}) async {
    final nomController = TextEditingController(text: client?.nom ?? '');
    final adresseController = TextEditingController(text: client?.adresse ?? '');
    final telephoneController = TextEditingController(text: client?.telephone ?? '');
    final emailController = TextEditingController(text: client?.email ?? '');
    double? latitude = client?.latitude;
    double? longitude = client?.longitude;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Nouveau client' : 'Modifier le client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom / Raison sociale')),
              const SizedBox(height: 8),
              AddressAutocompleteField(
                controller: adresseController,
                labelText: 'Adresse',
                onAdresseSelectionnee: (suggestion) {
                  latitude = suggestion.latitude;
                  longitude = suggestion.longitude;
                },
              ),
              const SizedBox(height: 8),
              TextField(controller: telephoneController, decoration: const InputDecoration(labelText: 'Téléphone')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (confirme != true || nomController.text.trim().isEmpty) return;

    if (client == null) {
      final nouveau = Client(
        id: const Uuid().v4(),
        nom: nomController.text.trim(),
        adresse: adresseController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        telephone: telephoneController.text.trim().isEmpty ? null : telephoneController.text.trim(),
        email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
        dateCreation: DateTime.now(),
      );
      await DatabaseHelper.instance.insertClient(nouveau);
    } else {
      client.nom = nomController.text.trim();
      client.adresse = adresseController.text.trim();
      client.latitude = latitude;
      client.longitude = longitude;
      client.telephone = telephoneController.text.trim().isEmpty ? null : telephoneController.text.trim();
      client.email = emailController.text.trim().isEmpty ? null : emailController.text.trim();
      await DatabaseHelper.instance.updateClient(client);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _rechercheController,
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rechercheController.clear();
                          setState(() => _recherche = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _recherche = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: _futureClients,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final clients = snapshot.data!.where((c) {
                  if (_recherche.trim().isEmpty) return true;
                  final motif = _recherche.toLowerCase();
                  return c.nom.toLowerCase().contains(motif) || c.adresse.toLowerCase().contains(motif);
                }).toList();

                if (clients.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Aucun client. Appuyez sur + pour en ajouter un.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            child: Text(
                              client.nom.isNotEmpty ? client.nom[0].toUpperCase() : '?',
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(client.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(client.adresse, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: client.id)),
                            );
                            _reload();
                          },
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
        onPressed: () => _creerOuEditerClient(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Client'),
      ),
    );
  }
}
