from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
issues: list[str] = []

def read(rel: str) -> str:
    p = ROOT / rel
    if not p.exists():
        issues.append(f"missing required file: {rel}")
        return ""
    return p.read_text(encoding="utf-8", errors="ignore")

pubspec = read("pubspec.yaml")
environment = read("lib/core/config/app_environment.dart")
route_service = read("lib/core/routing/route_planning_service.dart")
all_lib = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in (ROOT / "lib").rglob("*.dart"))

if "defaultValue: 'production'" not in environment:
    issues.append("APP_ENV must default to production")
if "ENABLE_LOCAL_DEMO" in all_lib or "localDemoModeProvider" in all_lib:
    issues.append("demo runtime switch found in production source")
if (ROOT / "lib/data/mock").exists() or (ROOT / "lib/core/dev").exists():
    issues.append("demo/mock source directories must not exist")
if "service_role" in all_lib.lower() or "service-role" in all_lib.lower():
    issues.append("service-role secret marker found in client code")
if "valhalla.openstreetmap.de/route" in route_service:
    issues.append("obsolete Valhalla web frontend is still configured as an API endpoint")
if re.search(r"\.from\(['\"]activities['\"]\)\.(?:insert|update|upsert)", all_lib):
    issues.append("direct activities mutation found; critical writes must use RPC")
if re.search(r"\.from\(['\"]groups['\"]\)\.(?:insert|update|upsert)", all_lib):
    issues.append("direct groups mutation found; critical writes must use RPC")
if (ROOT / "test/widget_test.dart").exists():
    issues.append("Flutter template widget_test.dart must not be committed")
if (ROOT / "test/mock_repository_test.dart").exists():
    issues.append("mock repository tests must not exist")
if "version: 0.4.1+43" not in pubspec:
    issues.append("unexpected app version for v0.4.1")

if issues:
    print("WayCrew project audit FAILED:")
    for issue in issues:
        print(f" - {issue}")
    sys.exit(1)

print("WayCrew project audit passed.")
