# Visite PV & Batterie

Application Android (Flutter) pour réaliser des visites techniques d'installations
photovoltaïques et de systèmes de stockage par batteries (BESS) : photos géolocalisées,
notes, mesures, checklist réglementaire paramétrable, et génération d'un rapport PDF
partageable à la fin de chaque visite.

Tout est stocké **localement sur le téléphone** (base SQLite + photos dans le stockage
de l'application), sans connexion réseau requise sur le terrain.

## ⚠️ Avertissement réglementaire important

Les checklists fournies (`assets/regulatory/checklist_pv.json` et
`checklist_batterie.json`) sont des **modèles indicatifs, non contractuels**.

Les distances réglementaires, exigences de compartimentage, accès pompiers, seuils
ICPE, etc. pour les installations photovoltaïques et les systèmes de stockage par
batteries dépendent :
- de la puissance/capacité de l'installation,
- du type de bâtiment (habitation, ERP, ICPE...),
- des textes en vigueur au moment de la visite (arrêtés, DTU, guides UTE C15-712-1/2/3),
- et surtout du **référentiel du SDIS territorialement compétent**, qui peut varier
  d'un département à l'autre.

**Aucune valeur numérique de l'application ne doit être considérée comme une valeur
réglementaire figée.** Toutes les valeurs de distance sont modifiables :
- par visite, directement dans l'onglet Checklist ;
- par défaut pour toutes les nouvelles visites, dans l'écran Réglages.

Avant chaque visite, vérifiez les exigences applicables auprès du SDIS local, du
bureau de contrôle et des textes réglementaires en vigueur.

## Fonctionnalités

- Création de visites (client, adresse, type d'installation PV / Batterie / mixte, date, technicien)
- Capture GPS de la position du site
- Prise de photos (caméra ou galerie) avec légende, par visite
- Notes générales libres
- Checklist réglementaire paramétrable, distincte pour le photovoltaïque et les
  batteries, avec repérage visuel des points "à vérifier sur site"
- Génération d'un rapport PDF complet (infos, checklist, notes, photos) et partage
  direct (mail, messagerie, etc.)
- Fonctionnement 100% hors-ligne

## Stack technique

- [Flutter](https://flutter.dev) (Dart) — packages principaux : `sqflite`,
  `image_picker`, `geolocator`, `pdf` / `printing`, `share_plus`, `shared_preferences`
- Android uniquement (le dossier `android/` est généré automatiquement, voir plus bas)

## Générer l'APK

Le dossier `android/` (fichiers Gradle, wrapper, manifest) **n'est pas versionné** :
il est régénéré automatiquement pour correspondre exactement à la version de Flutter
utilisée, ce qui évite les incompatibilités de version Gradle/AGP. Un script ajoute
ensuite les permissions nécessaires (caméra, stockage, localisation).

### Option 1 : Automatique via GitHub Actions (recommandé)

Chaque push sur `main` ou une branche `claude/**` déclenche le workflow
`.github/workflows/build-apk.yml`, qui :
1. installe Flutter,
2. génère le dossier `android/`,
3. ajoute les permissions,
4. compile l'APK en mode release,
5. le publie comme **artifact téléchargeable** sur la page du run (onglet *Actions*
   du dépôt GitHub, section *Artifacts*).

Téléchargez `visite-pv-batterie-apk.zip`, dézippez, puis transférez le fichier
`app-release.apk` sur votre téléphone Android pour l'installer (autoriser
l'installation d'applications hors Play Store si demandé).

### Option 2 : En local

Prérequis : [Flutter SDK](https://docs.flutter.dev/get-started/install) installé et
`flutter doctor` sans erreur bloquante pour Android.

```bash
flutter create --platforms=android --org com.motovisite .
python3 scripts/patch_android_manifest.py
flutter pub get
flutter build apk --release
```

L'APK se trouve ensuite dans `build/app/outputs/flutter-apk/app-release.apk`, à
copier sur le téléphone pour installation.

## Personnaliser les checklists réglementaires

Les fichiers `assets/regulatory/checklist_pv.json` et `checklist_batterie.json`
définissent les sections et champs de chaque checklist. Vous pouvez :
- modifier les libellés, ajouter/retirer des champs directement dans ces fichiers JSON,
- ou ajuster les valeurs indicatives par défaut depuis l'écran **Réglages** de
  l'application (sans toucher au code).

## Limites connues

- Testé uniquement par génération de code (aucun environnement Flutter n'était
  disponible pour compiler/exécuter l'app pendant son développement) : une vérification
  avec `flutter analyze` / `flutter build apk` réels est recommandée avant usage terrain,
  notamment pour confirmer la compatibilité des versions de packages listées dans
  `pubspec.yaml`.
- Pas de sauvegarde cloud : pensez à exporter/partager régulièrement vos rapports PDF.
