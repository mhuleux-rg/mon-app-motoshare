#!/usr/bin/env python3
"""
Ajoute au AndroidManifest.xml généré par `flutter create` les permissions
nécessaires à l'application (caméra, stockage, géolocalisation).

Usage : python3 scripts/patch_android_manifest.py
À exécuter après `flutter create --platforms=android .` et avant
`flutter build apk`.
"""
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

MANIFEST_PATH = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "AndroidManifest.xml"

PERMISSIONS = [
    "android.permission.CAMERA",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_EXTERNAL_STORAGE",
]


def main() -> None:
    if not MANIFEST_PATH.exists():
        raise SystemExit(
            f"AndroidManifest.xml introuvable à {MANIFEST_PATH}. "
            "Exécutez d'abord 'flutter create --platforms=android .' à la racine du projet."
        )

    tree = ET.parse(MANIFEST_PATH)
    root = tree.getroot()

    android_attr = f"{{{ANDROID_NS}}}name"
    existing = {
        el.get(android_attr)
        for el in root.findall("uses-permission")
    }

    inserted = 0
    for permission in PERMISSIONS:
        if permission in existing:
            continue
        element = ET.Element("uses-permission")
        element.set(android_attr, permission)
        root.insert(0, element)
        inserted += 1

    if inserted:
        tree.write(MANIFEST_PATH, encoding="utf-8", xml_declaration=True)
        print(f"{inserted} permission(s) ajoutée(s) dans {MANIFEST_PATH}")
    else:
        print("Toutes les permissions étaient déjà présentes.")


if __name__ == "__main__":
    main()
