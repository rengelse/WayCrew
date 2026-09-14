# WayCrew – GitHub setup

Denne pakken er laget for repoet `rengelse/WayCrew`.

## 1. Last opp prosjektet

Pakk ut ZIP-en og legg **innholdet i mappen** i roten av GitHub-repoet.

Ved push til `main` kjører GitHub Actions automatisk:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- signerer APK med WayCrew sin faste release-nøkkel
- laster opp `WayCrew-vX.Y.Z.apk` som Actions-artifact

Ved tag som starter med `v`, f.eks. `v0.4.1`, gjør workflowen det samme og publiserer APK-en på **GitHub Releases**. WayCrew sin innebygde oppdateringssjekk bruker disse GitHub Releases.

## 2. Lag permanent Android signing key én gang

På Windows med Java/keytool tilgjengelig:

```powershell
keytool -genkeypair -v -keystore waycrew-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias waycrew
```

**Ta sikkerhetskopi av `waycrew-release.jks`. Mister du nøkkelen, kan du ikke signere framtidige oppdateringer med samme app-identitet.**

## 3. Base64-kod keystore på Windows

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\waycrew-release.jks")) | Set-Content -NoNewline waycrew-keystore-base64.txt
```

## 4. Opprett GitHub Actions Secrets

I repoet:

`Settings -> Secrets and variables -> Actions -> New repository secret`

Opprett:

- `ANDROID_KEYSTORE_BASE64` – hele innholdet fra `waycrew-keystore-base64.txt`
- `ANDROID_KEYSTORE_PASSWORD` – passordet til keystore
- `ANDROID_KEY_ALIAS` – `waycrew` hvis du brukte kommandoen over
- `ANDROID_KEY_PASSWORD` – nøkkelpassordet

Keystore/passord skal aldri committes til repoet.

**Release-signering kreves disse secrets også ved vanlig push til `main`, fordi debug-build er fjernet og alle APK-er bygges som signert release.**

## 5. Lag en GitHub Release

Versjonen i `pubspec.yaml` og taggen må være identiske. For v0.4.1:

```powershell
git tag v0.4.1
git push origin v0.4.1
```

GitHub Actions validerer taggen og lager:

`WayCrew-v0.4.1.apk`

APK-en legges automatisk på GitHub Releases.

## 6. Oppdateringsfunksjonen i appen

WayCrew sjekker:

`https://api.github.com/repos/rengelse/WayCrew/releases/latest`

Appen sammenligner installert versjon med `tag_name` på siste release. Dersom GitHub har en nyere versjon:

- vises varsel i appen
- installert og ny versjon vises
- `Last ned` åpner APK-asset direkte når releasen inneholder en `.apk`
- hvis APK-asset mangler, åpnes selve GitHub Release-siden

Automatisk sjekk begrenses for å unngå unødvendige API-kall. Manuell sjekk finnes under `Innstillinger -> Om -> Sjekk etter oppdatering`.

## Android installasjonsadvarsel

APK-en blir korrekt release-signert med fast nøkkel. Ved direkte sideloading fra GitHub kan Android fortsatt vise sikkerhetsvarsel om installasjon fra ukjent kilde. Dette kan ikke fjernes av WayCrew-koden. Google Play-distribusjon gir den vanlige butikk-installasjonsflyten.

## CI-notater

- Java 21 brukes fordi MapLibre Android krever source release 21.
- Flutter sin genererte `test/widget_test.dart` fjernes etter `flutter create`; WayCrew sine egne tester beholdes og kjøres.
