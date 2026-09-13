# v0.2.5 Live Tracking – mobiloppsett

## Android

`geolocator` trenger eksplisitte Android-permissions. Fra prosjektroten på Windows kan disse legges inn idempotent med:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\patch_android_live_tracking.ps1
```

Scriptet legger til:

- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_LOCATION`
- `WAKE_LOCK`

Appen spør deretter om posisjon når en godkjent deltaker åpner en aktivitet som er `active` eller `paused`.

På nyere Android må brukeren normalt gi vanlig posisjonstilgang først. For pålitelig sporing når appen ligger i bakgrunnen må «Tillat hele tiden» / background location også gis i Androids appinnstillinger. Appen bruker en synlig foreground-service-varsling mens tracking kjører.

## iOS

Når iOS-prosjektet opprettes, legg minst inn `NSLocationWhenInUseUsageDescription` i `ios/Runner/Info.plist`. Før bakgrunnssporing distribueres på iOS må background location capability og relevante Info.plist-tekster konfigureres og testes separat.

## Personvern

- Ingen aktiv aktivitet = ingen live GPS-publisering.
- Bare godkjente/aktive deltakere kan publisere posisjon.
- Eksakte deltakerposisjoner er tilgjengelige kun for deltakere i aktiviteten.
- Offentlig kart bruker avrundet gruppeposisjon (`activity_public_state`), ikke rå individuell GPS.
- «Vis omtrentlig gruppeposisjon offentlig» kan slås av; valget lagres lokalt og synkes umiddelbart til live-raden.
- Når aktiviteten avsluttes eller avlyses, stopper serveren deling og fjerner offentlig live-state.
