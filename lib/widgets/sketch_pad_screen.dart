import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class _TraitDessin {
  final List<Offset> points;
  final Color couleur;
  final double epaisseur;

  _TraitDessin({required this.points, required this.couleur, required this.epaisseur});
}

/// Écran de croquis à main levée (implantation, distances, accès...),
/// exporté en image PNG et rattaché à la visite comme une photo.
class SketchPadScreen extends StatefulWidget {
  const SketchPadScreen({super.key});

  @override
  State<SketchPadScreen> createState() => _SketchPadScreenState();
}

class _SketchPadScreenState extends State<SketchPadScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_TraitDessin> _traits = [];
  _TraitDessin? _traitEnCours;

  Color _couleur = Colors.black87;
  double _epaisseur = 3;

  static const _palette = [
    Colors.black87,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  void _demarrerTrait(DragStartDetails details) {
    setState(() {
      _traitEnCours = _TraitDessin(
        points: [details.localPosition],
        couleur: _couleur,
        epaisseur: _epaisseur,
      );
    });
  }

  void _continuerTrait(DragUpdateDetails details) {
    setState(() {
      _traitEnCours?.points.add(details.localPosition);
    });
  }

  void _terminerTrait(DragEndDetails details) {
    if (_traitEnCours != null) {
      setState(() {
        _traits.add(_traitEnCours!);
        _traitEnCours = null;
      });
    }
  }

  void _annulerDernierTrait() {
    if (_traits.isEmpty) return;
    setState(() => _traits.removeLast());
  }

  void _effacerTout() {
    if (_traits.isEmpty) return;
    setState(() => _traits.clear());
  }

  Future<void> _enregistrer() async {
    if (_traits.isEmpty) {
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
        title: const Text('Croquis du site'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Annuler le dernier trait',
            onPressed: _annulerDernierTrait,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Tout effacer',
            onPressed: _effacerTout,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _enregistrer,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                for (final couleur in _palette) ...[
                  _PastilleCouleur(
                    couleur: couleur,
                    selectionnee: couleur == _couleur,
                    onTap: () => setState(() => _couleur = couleur),
                  ),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                const Icon(Icons.line_weight, size: 18, color: Colors.grey),
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
          ),
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: GestureDetector(
                  onPanStart: _demarrerTrait,
                  onPanUpdate: _continuerTrait,
                  onPanEnd: _terminerTrait,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SketchPainter(
                      traits: [..._traits, if (_traitEnCours != null) _traitEnCours!],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
        width: 28,
        height: 28,
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

class _SketchPainter extends CustomPainter {
  final List<_TraitDessin> traits;

  _SketchPainter({required this.traits});

  @override
  void paint(Canvas canvas, Size size) {
    for (final trait in traits) {
      final peinture = Paint()
        ..color = trait.couleur
        ..strokeWidth = trait.epaisseur
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < trait.points.length - 1; i++) {
        canvas.drawLine(trait.points[i], trait.points[i + 1], peinture);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
