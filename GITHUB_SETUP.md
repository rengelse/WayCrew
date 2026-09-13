# WayCrew – GitHub setup

Denne pakken kan legges direkte i GitHub-repoet `rengelse/WayCrew`.

## 1. Last opp prosjektet

Pakk ut ZIP-en og legg **innholdet i mappen** i roten av GitHub-repoet.

Når filer pushes til `main`, kjører GitHub Actions automatisk:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- bygger en debug-APK som Actions-artifact

Når du lager en tag som starter med `v`, for eksempel `v0.2.15`, bygger workflowen en permanent signert release-APK og publiserer den på GitHub Releases.

## 2. Lag permanent Android signing key én gang

På Windows med Java/keytool tilgjengelig:

```powershell
keytool -genkeypair -v -keystore waycrew-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias waycrew
```

**Ta sikkerhetskopi av `waycrew-release.jks`. Mister du nøkkelen, kan du ikke signere framtidige oppdateringer med samme identitet.**

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

## 5. Lag første release

Etter at secrets er satt, lag/push tag:

```powershell
git tag v0.2.15
git push origin v0.2.15
```

GitHub Actions lager da:

`WayCrew-v0.2.15.apk`

og legger APK-en automatisk på GitHub Releases.

## Android installasjonsadvarsel

APK-en blir korrekt release-signert med fast nøkkel. Ved direkte sideloading fra GitHub kan Android fortsatt vise sikkerhetsvarsel om installasjon fra ukjent kilde. Det kan ikke fjernes av appkode. Distribusjon gjennom Google Play er veien til vanlig Play Store-installasjon uten denne sideload-flyten.


## v0.2.16 CI note

The workflow removes Flutter's generated `test/widget_test.dart` after `flutter create`, because that template references `MyApp` and is not part of WayCrew. Project tests under `test/` are preserved and still executed.
