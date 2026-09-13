import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

enum _Outil { stylo, ligne, cercle, rectangle, texte }

class _PictoDef {
  final IconData icone;
  final String label;

  const _PictoDef(this.icone, this.label);
}

const _categoriesPictos = <String, List<_PictoDef>>{
  'Équipements': [
    _PictoDef(Icons.solar_power, 'PV'),
    _PictoDef(Icons.battery_charging_full, 'Batterie'),
    _PictoDef(Icons.garage_outlined, 'Ombrière'),
    _PictoDef(Icons.bolt, 'Poste HTA'),
    _PictoDef(Icons.speed, 'Compteur'),
  ],
  'Bâtiment et accès': [
    _PictoDef(Icons.home_outlined, 'Bâtiment'),
    _PictoDef(Icons.directions_car_outlined, 'Accès véhicule'),
  ],
  'Sécurité': [
    _PictoDef(Icons.local_fire_department_outlined, 'Extincteur'),
    _PictoDef(Icons.warning_amber_rounded, 'Danger'),
  ],
};

const _palette = [
  Colors.black87,
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
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

class _FormeRectangle extends _Element {
  final Offset coin1;
  final Offset coin2;
  @override
  final Color couleur;
  final double epaisseur;

  _FormeRectangle({required this.coin1, required this.coin2, required this.couleur, required this.epaisseur});
}

class _PictoPose extends _Element {
  Offset position;
  final IconData icone;
  final String label;
  @override
  Color couleur;

  _PictoPose({required this.position, required this.icone, required this.label, required this.couleur});
}

class _TextePose extends _Element {
  Offset position;
  String texte;
  @override
  Color couleur;

  _TextePose({required this.position, required this.texte, required this.couleur});
}

/// Éditeur de plan de masse : import d'une image de fond (plan cadastral,
/// vue satellite, plan papier photographié...), annotation libre (stylo,
/// ligne, cercle, rectangle, texte, en plusieurs couleurs), pictogrammes
/// déplaçables (PV, batterie, ombrière, poste HTA...) et zoom à 2 doigts
/// pour annoter précisément. Le résultat est exporté en PNG.
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
  _FormeRectangle? _rectangleEnCours;
  Offset? _positionTexteEnAttente;

  _Outil _outil = _Outil.stylo;
  Color _couleur = Colors.black87;
  double _epaisseur = 3;
  Uint8List? _imageFond;
  Size _tailleVue = const Size(300, 300);

  // Zoom / déplacement à 2 doigts (le dessin reste au 1 doigt).
  double _echelle = 1.0;
  double _echelleDebut = 1.0;
  Offset _decalage = Offset.zero;
  Offset _decalageDebut = Offset.zero;
  Offset _pointFocalDebut = Offset.zero;

  Future<void> _importerPlan() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() => _imageFond = bytes);
  }

  Offset get _centreVueEnEspacePlan => _versEspacePlan(Offset(_tailleVue.width / 2, _tailleVue.height / 2));

  Future<void> _ouvrirPalettePictos() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ajouter un pictogramme', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Text(
                  'Appuyez sur un picto pour le placer au centre du plan, puis glissez-le où vous voulez.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                for (final categorie in _categoriesPictos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(
                      categorie.key.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final def in categorie.value) _boutonPicto(def),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _boutonPicto(_PictoDef def) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _ajouterPicto(def),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(def.icone, color: _couleur),
            ),
            const SizedBox(height: 4),
            Text(def.label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _ajouterPicto(_PictoDef def) {
    setState(() {
      _elements.add(_PictoPose(position: _centreVueEnEspacePlan, icone: def.icone, label: def.label, couleur: _couleur));
    });
  }

  Future<void> _demanderTexte(Offset position, {_TextePose? existant}) async {
    final controller = TextEditingController(text: existant?.texte ?? '');
    final resultat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existant == null ? 'Ajouter un texte' : 'Modifier le texte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Ex : 3,20 m'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Valider')),
        ],
      ),
    );
    if (resultat == null || resultat.isEmpty) return;
    setState(() {
      if (existant != null) {
        existant.texte = resultat;
      } else {
        _elements.add(_TextePose(position: position, texte: resultat, couleur: _couleur));
      }
    });
  }

  /// Convertit un point exprimé dans l'espace écran (celui du geste) en
  /// coordonnées du plan (indépendantes du zoom/déplacement courant), afin
  /// que les traits restent alignés avec le fond quel que soit le niveau
  /// de zoom au moment où ils sont dessinés.
  Offset _versEspacePlan(Offset ecran) => (ecran - _decalage) / _echelle;

  void _onScaleStart(ScaleStartDetails details) {
    _echelleDebut = _echelle;
    _decalageDebut = _decalage;
    _pointFocalDebut = details.localFocalPoint;
    if (details.pointerCount == 1) {
      _debutGeste(_versEspacePlan(details.localFocalPoint));
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      // Un 2e doigt est posé : on passe en zoom/déplacement et on annule
      // un éventuel tracé entamé au doigt unique juste avant.
      _traitEnCours = null;
      _ligneEnCours = null;
      _cercleEnCours = null;
      _rectangleEnCours = null;
      _positionTexteEnAttente = null;
      setState(() {
        _echelle = (_echelleDebut * details.scale).clamp(1.0, 6.0);
        _decalage = _decalageDebut + (details.localFocalPoint - _pointFocalDebut);
      });
    } else {
      _majGeste(_versEspacePlan(details.localFocalPoint));
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _finGeste();
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
      case _Outil.rectangle:
        setState(() => _rectangleEnCours = _FormeRectangle(coin1: position, coin2: position, couleur: _couleur, epaisseur: _epaisseur));
        break;
      case _Outil.texte:
        _positionTexteEnAttente = position;
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
      case _Outil.rectangle:
        if (_rectangleEnCours != null) {
          setState(() => _rectangleEnCours = _FormeRectangle(
                coin1: _rectangleEnCours!.coin1,
                coin2: position,
                couleur: _rectangleEnCours!.couleur,
                epaisseur: _rectangleEnCours!.epaisseur,
              ));
        }
        break;
      case _Outil.texte:
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
      if (_rectangleEnCours != null) {
        _elements.add(_rectangleEnCours!);
        _rectangleEnCours = null;
      }
    });
    if (_outil == _Outil.texte && _positionTexteEnAttente != null) {
      final position = _positionTexteEnAttente!;
      _positionTexteEnAttente = null;
      _demanderTexte(position);
    }
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
    // On exporte toujours le plan à l'échelle complète (zoom 1:1), quel que
    // soit le niveau de zoom affiché au moment de l'enregistrement.
    if (_echelle != 1.0 || _decalage != Offset.zero) {
      setState(() {
        _echelle = 1.0;
        _decalage = Offset.zero;
      });
      await WidgetsBinding.instance.endOfFrame;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                _tailleVue = constraints.biggest;
                return RepaintBoundary(
                  key: _repaintKey,
                  child: Container(
                    color: Colors.white,
                    width: double.infinity,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        if (_imageFond != null)
                          Positioned.fill(
                            child: Transform(
                              alignment: Alignment.topLeft,
                              transform: Matrix4.identity()
                                ..translate(_decalage.dx, _decalage.dy)
                                ..scale(_echelle),
                              child: Image.memory(_imageFond!, fit: BoxFit.contain),
                            ),
                          ),
                        Positioned.fill(
                          child: GestureDetector(
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            onScaleEnd: _onScaleEnd,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _PlanPainter(
                                elements: _elements,
                                traitEnCours: _traitEnCours,
                                ligneEnCours: _ligneEnCours,
                                cercleEnCours: _cercleEnCours,
                                rectangleEnCours: _rectangleEnCours,
                                echelle: _echelle,
                                decalage: _decalage,
                              ),
                            ),
                          ),
                        ),
                        for (final element in _elements)
                          if (element is _PictoPose) _pictoDeplacable(element),
                        for (final element in _elements)
                          if (element is _TextePose) _texteDeplacable(element),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: _boutonZoomInfo(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirPalettePictos,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Picto'),
      ),
    );
  }

  Widget _boutonZoomInfo() {
    if (_echelle <= 1.01) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() {
        _echelle = 1.0;
        _decalage = Offset.zero;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.zoom_out, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text('${(_echelle * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Offset _positionEcran(Offset positionPlan) => _decalage + positionPlan * _echelle;

  Future<void> _menuElement(_Element element, Offset positionEcranTap) async {
    final choix = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(positionEcranTap.dx, positionEcranTap.dy, positionEcranTap.dx, positionEcranTap.dy),
      items: [
        if (element is _TextePose) const PopupMenuItem(value: 'modifier', child: Text('Modifier le texte')),
        const PopupMenuItem(value: 'couleur', child: Text('Changer la couleur')),
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
      ],
    );
    if (choix == 'supprimer') {
      setState(() => _elements.remove(element));
    } else if (choix == 'couleur') {
      final couleur = await _choisirCouleurDialogue();
      if (couleur != null) {
        setState(() {
          if (element is _PictoPose) element.couleur = couleur;
          if (element is _TextePose) element.couleur = couleur;
        });
      }
    } else if (choix == 'modifier' && element is _TextePose) {
      _demanderTexte(element.position, existant: element);
    }
  }

  Future<Color?> _choisirCouleurDialogue() {
    return showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une couleur'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final couleur in _palette)
              GestureDetector(
                onTap: () => Navigator.pop(context, couleur),
                child: Container(width: 36, height: 36, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pictoDeplacable(_PictoPose picto) {
    final position = _positionEcran(picto.position);
    return Positioned(
      left: position.dx - 22,
      top: position.dy - 22,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => picto.position += d.delta / _echelle),
        onTapUp: (d) => _menuElement(picto, d.globalPosition),
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

  Widget _texteDeplacable(_TextePose element) {
    final position = _positionEcran(element.position);
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => element.position += d.delta / _echelle),
        onTapUp: (d) => _menuElement(element, d.globalPosition),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: Border.all(color: element.couleur),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(element.texte, style: TextStyle(color: element.couleur, fontWeight: FontWeight.w600, fontSize: 13)),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _boutonOutil(_Outil.stylo, Icons.edit_outlined, 'Stylo'),
                _boutonOutil(_Outil.ligne, Icons.show_chart, 'Ligne'),
                _boutonOutil(_Outil.cercle, Icons.circle_outlined, 'Cercle'),
                _boutonOutil(_Outil.rectangle, Icons.crop_square, 'Rectangle'),
                _boutonOutil(_Outil.texte, Icons.text_fields, 'Texte'),
                const SizedBox(width: 10),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                const SizedBox(width: 10),
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
  final _FormeRectangle? rectangleEnCours;
  final double echelle;
  final Offset decalage;

  _PlanPainter({
    required this.elements,
    this.traitEnCours,
    this.ligneEnCours,
    this.cercleEnCours,
    this.rectangleEnCours,
    required this.echelle,
    required this.decalage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(decalage.dx, decalage.dy);
    canvas.scale(echelle);

    for (final element in elements) {
      _dessinerElement(canvas, element);
    }
    if (traitEnCours != null) _dessinerElement(canvas, traitEnCours!);
    if (ligneEnCours != null) _dessinerElement(canvas, ligneEnCours!);
    if (cercleEnCours != null) _dessinerElement(canvas, cercleEnCours!);
    if (rectangleEnCours != null) _dessinerElement(canvas, rectangleEnCours!);

    canvas.restore();
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
    } else if (element is _FormeRectangle) {
      final peinture = Paint()
        ..color = element.couleur
        ..strokeWidth = element.epaisseur
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromPoints(element.coin1, element.coin2), peinture);
    }
    // _PictoPose et _TextePose ne sont pas dessinés ici : rendus via des
    // widgets Positioned déplaçables, repositionnés selon le zoom courant.
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) => true;
}
