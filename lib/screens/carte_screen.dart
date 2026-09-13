import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../db/database_helper.dart';
import '../models/visite.dart';
import 'visite_detail_screen.dart';

/// Carte interactive (OpenStreetMap, sans clé API) montrant un marqueur par
/// visite géolocalisée. Nécessite une connexion internet pour charger les
/// tuiles de la carte.
class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});

  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  static const _centreParDefaut = LatLng(46.6, 2.4); // Centre approximatif de la France
  final MapController _controleurCarte = MapController();

  List<Visite> _visites = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final toutes = await DatabaseHelper.instance.getVisites();
    setState(() {
      _visites = toutes.where((v) => v.latitude != null && v.longitude != null).toList();
      _chargement = false;
    });
    if (_visites.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controleurCarte.move(
          LatLng(_visites.first.latitude!, _visites.first.longitude!),
          _visites.length > 1 ? 6 : 13,
        );
      });
    }
  }

  Color _couleurPourVisite(Visite visite) {
    if (visite.cloturee) return const Color(0xFF0E6E52);
    switch (visite.type) {
      case TypeInstallation.photovoltaique:
        return const Color(0xFF0E6E52);
      case TypeInstallation.batterie:
        return const Color(0xFFB2650A);
      case TypeInstallation.mixte:
        return const Color(0xFF2B5FA6);
    }
  }

  IconData _iconePourVisite(Visite visite) {
    switch (visite.type) {
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
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_visites.isEmpty ? 'Carte des visites' : 'Carte des visites (${_visites.length})'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controleurCarte,
            options: const MapOptions(
              initialCenter: _centreParDefaut,
              initialZoom: 5,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.motovisite.visite_pv',
              ),
              MarkerLayer(
                markers: [
                  for (final visite in _visites)
                    Marker(
                      point: LatLng(visite.latitude!, visite.longitude!),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VisiteDetailScreen(visiteId: visite.id)),
                          );
                          _charger();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _couleurPourVisite(visite),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Icon(_iconePourVisite(visite), color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_visites.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Aucune visite géolocalisée pour l'instant. Choisissez une adresse suggérée "
                          "(une liste apparaît sous le champ pendant la saisie) ou capturez la position GPS "
                          "d'une visite pour la voir apparaître ici.",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
