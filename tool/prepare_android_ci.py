from __future__ import annotations

import argparse
import shutil
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
MANIFEST = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
RES = ANDROID / "app" / "src" / "main" / "res"
BRANDING = ROOT / "tool" / "waycrew_branding" / "res"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

PERMISSIONS = [
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.WAKE_LOCK",
]


def configure_manifest() -> None:
    if not MANIFEST.exists():
        raise SystemExit(f"Missing AndroidManifest.xml: {MANIFEST}")

    tree = ET.parse(MANIFEST)
    root = tree.getroot()
    existing = {
        node.attrib.get(f"{{{ANDROID_NS}}}name")
        for node in root.findall("uses-permission")
    }
    for permission in PERMISSIONS:
        if permission not in existing:
            node = ET.Element("uses-permission")
            node.set(f"{{{ANDROID_NS}}}name", permission)
            root.insert(0, node)

    application = root.find("application")
    if application is None:
        raise SystemExit("Missing <application> in AndroidManifest.xml")
    application.set(f"{{{ANDROID_NS}}}label", "WayCrew")
    tree.write(MANIFEST, encoding="utf-8", xml_declaration=True)


def copy_branding() -> None:
    for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        source = BRANDING / f"mipmap-{density}"
        target = RES / f"mipmap-{density}"
        target.mkdir(parents=True, exist_ok=True)
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            src = source / name
            if not src.exists():
                raise SystemExit(f"Missing branding asset: {src}")
            shutil.copy2(src, target / name)


def configure_signing() -> None:
    gradle_kts = ANDROID / "app" / "build.gradle.kts"
    if not gradle_kts.exists():
        raise SystemExit(f"Missing Gradle file: {gradle_kts}")

    text = gradle_kts.read_text(encoding="utf-8")
    if "waycrew release signing" in text:
        return

    imports = "import java.util.Properties\nimport java.io.FileInputStream\n\n"
    if not text.startswith("import java.util.Properties"):
        text = imports + text

    marker = "android {"
    setup = '''// waycrew release signing\nval keystoreProperties = Properties()\nval keystorePropertiesFile = rootProject.file("key.properties")\nif (keystorePropertiesFile.exists()) {\n    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n}\n\n'''
    if marker not in text:
        raise SystemExit("Could not find android block in build.gradle.kts")
    text = text.replace(marker, setup + marker, 1)

    build_types = "    buildTypes {"
    signing_config = '''    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties["keyAlias"] as String\n            keyPassword = keystoreProperties["keyPassword"] as String\n            storeFile = file(keystoreProperties["storeFile"] as String)\n            storePassword = keystoreProperties["storePassword"] as String\n        }\n    }\n\n'''
    if build_types not in text:
        raise SystemExit("Could not find buildTypes block in build.gradle.kts")
    text = text.replace(build_types, signing_config + build_types, 1)

    debug_line = "signingConfig = signingConfigs.getByName(\"debug\")"
    if debug_line not in text:
        raise SystemExit("Could not find default release signing line in build.gradle.kts")
    text = text.replace(
        debug_line,
        "signingConfig = signingConfigs.getByName(\"release\")",
        1,
    )
    gradle_kts.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--signing", action="store_true")
    args = parser.parse_args()

    configure_manifest()
    copy_branding()
    if args.signing:
        configure_signing()
    print("WayCrew Android CI configuration applied.")


if __name__ == "__main__":
    main()
