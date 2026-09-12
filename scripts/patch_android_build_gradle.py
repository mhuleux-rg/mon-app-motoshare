#!/usr/bin/env python3
"""
Force compileSdk/targetSdk à une version Android récente dans le
android/app/build.gradle.kts généré par `flutter create`.

Certains plugins (ex: printing, image_picker...) exigent une API Android
plus récente que la valeur par défaut fournie par `flutter.compileSdkVersion`
selon la version de Flutter utilisée, ce qui fait échouer la compilation
avec des erreurs "CheckAarMetadataWorkAction". Fixer explicitement une
version récente évite ce problème plugin par plugin.

Usage : python3 scripts/patch_android_build_gradle.py
À exécuter après `flutter create --platforms=android .`.
"""
import re
from pathlib import Path

BUILD_GRADLE_PATH = (
    Path(__file__).resolve().parent.parent / "android" / "app" / "build.gradle.kts"
)

TARGET_SDK_VALUE = 36


def main() -> None:
    if not BUILD_GRADLE_PATH.exists():
        raise SystemExit(
            f"{BUILD_GRADLE_PATH} introuvable. "
            "Exécutez d'abord 'flutter create --platforms=android .' à la racine du projet."
        )

    content = BUILD_GRADLE_PATH.read_text(encoding="utf-8")
    original = content

    content = re.sub(
        r"compileSdk\s*=\s*flutter\.compileSdkVersion",
        f"compileSdk = {TARGET_SDK_VALUE}",
        content,
    )
    content = re.sub(
        r"targetSdk\s*=\s*flutter\.targetSdkVersion",
        f"targetSdk = {TARGET_SDK_VALUE}",
        content,
    )

    if content == original:
        print("Aucun remplacement effectué (motifs déjà absents ou déjà patchés).")
    else:
        BUILD_GRADLE_PATH.write_text(content, encoding="utf-8")
        print(f"compileSdk/targetSdk fixés à {TARGET_SDK_VALUE} dans {BUILD_GRADLE_PATH}")


if __name__ == "__main__":
    main()
