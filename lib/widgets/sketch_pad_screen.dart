import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

enum _Outil { stylo, ligne, cercle, deplacer }

class _PictoDef {
  final IconData icone;
  final String label;

  const _PictoDef(this.icone, this.label);
}

const _paletteIcones = [
  _PictoDef(Icons.solar_power, 'PV'),
  _PictoDef(Icons.battery_charging_full, 'Batterie'),
  _PictoDef(Icons.garage_outlined, 'Ombrière'),
  _PictoDef(Icons.bolt, 'Poste HTA'),
  _PictoDef(Icons.speed, 'Compteur'),
  _PictoDef(Icons.home_outlined, 'Bâtiment'),
  _PictoDef(Icons.directions_car_outlined, 'Accès véhicule'),
  _PictoDef(Icons.local_fire_department_outlined, 'Extincteur'),
  _PictoDef(Icons.warning_amber_rounded, 'Danger'),
];

abstract class _Element {
  Color get couleur;
}

class _TraitLibre extends _Element {
  final List<Offset> points;
  @override
  final Color couleur;
  final double epaisseur;

  _TraitLibre({required this.points, required this.couleur, required this.epaisseur});
}

class _FormeLigne extends _Element {
  final Offset debut;
  final Offset fin;
  @override
  final Color couleur;
  final double epaisseur;

  _FormeLigne({required this.debut, required this.fin, required this.couleur, required this.epaisseur});
}

class _FormeCercle extends _Element {
  final Offset centre;
  final double rayon;
  @override
  final Color couleur;
  final double epaisseur;

  _FormeCercle({required this.centre, required this.rayon, required this.couleur, required this.epaisseur});
}

class _PictoPose extends _Element {
  Offset position;
  final IconData icone;
  final String label;
  @override
  final Color couleur;

  _PictoPose({required this.position, required this.icone, required this.label, required this.couleur});
}

/// Éditeur de plan de masse : import d'une image de fond (plan cadastral,
/// vue satellite, plan papier photographié...), annotation libre (stylo,
/// lignes, cercles en plusieurs couleurs) et pictogrammes déplaçables
/// (PV, batterie, ombrière, poste HTA...). Le résultat est exporté en PNG.
class SketchPadScreen extends StatefulWidget {
  const SketchPadScreen({super.key});

  @override
  State<SketchPadScreen> createState() => _SketchPadScreenState();
}

class _SketchPadScreenState extends State<SketchPadScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_Element> _elements = [];
  _TraitLibre? _traitEnCours;
  _FormeLigne? _ligneEnCours;
  _FormeCercle? _cercleEnCours;

  _Outil _outil = _Outil.stylo;
  Color _couleur = Colors.black87;
  double _epaisseur = 3;
  Uint8List? _imageFond;

  static const _palette = [
    Colors.black87,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  Future<void> _importerPlan() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() => _imageFond = bytes);
  }

  void _ajouterPicto(_PictoDef def) {
    setState(() {
      _elements.add(
        _PictoPose(
          position: const Offset(140, 140),
          icone: def.icone,
          label: def.label,
          couleur: _couleur,
        ),
      );
    });
  }

  void _debutGeste(Offset position) {
    switch (_outil) {
      case _Outil.stylo:
        setState(() => _traitEnCours = _TraitLibre(points: [position], couleur: _couleur, epaisseur: _epaisseur));
        break;
      case _Outil.ligne:
        setState(() => _ligneEnCours = _FormeLigne(debut: position, fin: position, couleur: _couleur, epaisseur: _epaisseur));
        break;
      case _Outil.cercle:
        setState(() => _cercleEnCours = _FormeCercle(centre: position, rayon: 0, couleur: _couleur, epaisseur: _epaisseur));
        break;
      case _Outil.deplacer:
        break;
    }
  }

  void _majGeste(Offset position) {
    switch (_outil) {
      case _Outil.stylo:
        setState(() => _traitEnCours?.points.add(position));
        break;
      case _Outil.ligne:
        if (_ligneEnCours != null) {
          setState(() => _ligneEnCours = _FormeLigne(
                debut: _ligneEnCours!.debut,
                fin: position,
                couleur: _ligneEnCours!.couleur,
                epaisseur: _ligneEnCours!.epaisseur,
              ));
        }
        break;
      case _Outil.cercle:
        if (_cercleEnCours != null) {
          final rayon = (position - _cercleEnCours!.centre).distance;
          setState(() => _cercleEnCours = _FormeCercle(
                centre: _cercleEnCours!.centre,
                rayon: rayon,
                couleur: _cercleEnCours!.couleur,
                epaisseur: _cercleEnCours!.epaisseur,
              ));
        }
        break;
      case _Outil.deplacer:
        break;
    }
  }

  void _finGeste() {
    setState(() {
      if (_traitEnCours != null) {
        _elements.add(_traitEnCours!);
        _traitEnCours = null;
      }
      if (_ligneEnCours != null) {
        _elements.add(_ligneEnCours!);
        _ligneEnCours = null;
      }
      if (_cercleEnCours != null) {
        _elements.add(_cercleEnCours!);
        _cercleEnCours = null;
      }
    });
  }

  void _annulerDernier() {
    if (_elements.isEmpty) return;
    setState(() => _elements.removeLast());
  }

  void _effacerTout() {
    if (_elements.isEmpty && _imageFond == null) return;
    setState(() {
      _elements.clear();
      _imageFond = null;
    });
  }

  Future<void> _enregistrer() async {
    if (_elements.isEmpty && _imageFond == null) {
      Navigator.pop(context);
      return;
    }
    final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null && mounted) {
      Navigator.pop(context, byteData.buffer.asUint8List());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de masse'),
        actions: [
          IconButton(icon: const Icon(Icons.photo_outlined), tooltip: 'Importer un plan', onPressed: _importerPlan),
          IconButton(icon: const Icon(Icons.undo), tooltip: 'Annuler', onPressed: _annulerDernier),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Tout effacer', onPressed: _effacerTout),
          IconButton(icon: const Icon(Icons.check), tooltip: 'Enregistrer', onPressed: _enregistrer),
        ],
      ),
      body: Column(
        children: [
          _barreOutils(),
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: Stack(
                  children: [
                    if (_imageFond != null)
                      Positioned.fill(child: Image.memory(_imageFond!, fit: BoxFit.contain)),
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (d) => _debutGeste(d.localPosition),
                        onPanUpdate: (d) => _majGeste(d.localPosition),
                        onPanEnd: (_) => _finGeste(),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _PlanPainter(
                            elements: _elements,
                            traitEnCours: _traitEnCours,
                            ligneEnCours: _ligneEnCours,
                            cercleEnCours: _cercleEnCours,
                          ),
                        ),
                      ),
                    ),
                    for (final element in _elements)
                      if (element is _PictoPose) _pictoDeplacable(element),
                  ],
                ),
              ),
            ),
          ),
          _barrePictos(),
        ],
      ),
    );
  }

  Widget _pictoDeplacable(_PictoPose picto) {
    return Positioned(
      left: picto.position.dx - 22,
      top: picto.position.dy - 22,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => picto.position += d.delta),
        onLongPress: () => setState(() => _elements.remove(picto)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: picto.couleur, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
              ),
              child: Icon(picto.icone, color: picto.couleur, size: 22),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: Text(picto.label, style: TextStyle(fontSize: 9, color: picto.couleur, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreOutils() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            children: [
              _boutonOutil(_Outil.stylo, Icons.edit_outlined, 'Stylo'),
              _boutonOutil(_Outil.ligne, Icons.show_chart, 'Ligne'),
              _boutonOutil(_Outil.cercle, Icons.circle_outlined, 'Cercle'),
              const SizedBox(width: 12),
              for (final couleur in _palette) ...[
                _PastilleCouleur(
                  couleur: couleur,
                  selectionnee: couleur == _couleur,
                  onTap: () => setState(() => _couleur = couleur),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          Row(
            children: [
              const Icon(Icons.line_weight, size: 16, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: _epaisseur,
                  min: 1,
                  max: 10,
                  onChanged: (v) => setState(() => _epaisseur = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boutonOutil(_Outil outil, IconData icone, String label) {
    final selectionne = _outil == outil;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _outil = outil),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selectionne ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 20, color: selectionne ? Theme.of(context).colorScheme.primary : Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _barrePictos() {
    return Container(
      height: 76,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _paletteIcones.length,
        itemBuilder: (context, index) {
          final def = _paletteIcones[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _ajouterPicto(def),
              child: SizedBox(
                width: 62,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(def.icone, color: _couleur),
                    const SizedBox(height: 2),
                    Text(def.label, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PastilleCouleur extends StatelessWidget {
  final Color couleur;
  final bool selectionnee;
  final VoidCallback onTap;

  const _PastilleCouleur({required this.couleur, required this.selectionnee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: couleur,
          shape: BoxShape.circle,
          border: Border.all(
            color: selectionnee ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  final List<_Element> elements;
  final _TraitLibre? traitEnCours;
  final _FormeLigne? ligneEnCours;
  final _FormeCercle? cercleEnCours;

  _PlanPainter({required this.elements, this.traitEnCours, this.ligneEnCours, this.cercleEnCours});

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in elements) {
      _dessinerElement(canvas, element);
    }
    if (traitEnCours != null) _dessinerElement(canvas, traitEnCours!);
    if (ligneEnCours != null) _dessinerElement(canvas, ligneEnCours!);
    if (cercleEnCours != null) _dessinerElement(canvas, cercleEnCours!);
  }

  void _dessinerElement(Canvas canvas, _Element element) {
    if (element is _TraitLibre) {
      final peinture = Paint()
        ..color = element.couleur
        ..strokeWidth = element.epaisseur
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < element.points.length - 1; i++) {
        canvas.drawLine(element.points[i], element.points[i + 1], peinture);
      }
    } else if (element is _FormeLigne) {
      final peinture = Paint()
        ..color = element.couleur
        ..strokeWidth = element.epaisseur
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(element.debut, element.fin, peinture);
    } else if (element is _FormeCercle) {
      final peinture = Paint()
        ..color = element.couleur
        ..strokeWidth = element.epaisseur
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(element.centre, element.rayon, peinture);
    }
    // _PictoPose n'est pas dessiné ici : rendu via des widgets Positioned déplaçables.
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) => true;
}
