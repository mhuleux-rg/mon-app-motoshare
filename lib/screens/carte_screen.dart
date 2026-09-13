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

    if (_visites.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte des visites')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  "Aucune visite géolocalisée pour l'instant.\n"
                  "Choisissez une adresse suggérée ou capturez la position GPS d'une visite pour la voir apparaître ici.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final centre = LatLng(_visites.first.latitude!, _visites.first.longitude!);

    return Scaffold(
      appBar: AppBar(title: Text('Carte des visites (${_visites.length})')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: centre,
          initialZoom: _visites.length > 1 ? 6 : 13,
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
    );
  }
}
