# WayCrew v0.3.9

Gjeldende versjon: **0.3.9+41**. WayCrew har nå serverstyrt sletting av chatmeldinger med moderatorrettigheter og låst audit-spor.

# WayCrew

Gjeldende baseline: **v0.2.14 – Deletion & Branding Fix**.

## Etter UPDATE

Kjør Supabase-migreringen og Flutter-kontrollene:

```powershell
supabase db push
flutter pub get
flutter analyze
flutter test
flutter run
```

Fordi Android-host ble opprettet lokalt og ikke skal blindt overskrives av UPDATE-pakker, legges WayCrew-navn og launcher-ikon inn med den medfølgende, målrettede branding-jobben:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\apply_waycrew_android_branding.ps1
```

Scriptet endrer kun Android-appens label til `WayCrew` og erstatter launcher-ikonressursene. Det beholder øvrige Android-permissions/services/oppsett.


## Updates

WayCrew checks GitHub Releases for new versions at startup and from Settings → Om. Tagged releases publish a signed APK automatically.


## Route Planning
WayCrew v0.3.1 lagrer og viser planlagt rutegeometri med start, mellomstopp og mål. Landbaserte ruter beregnes med Valhalla/OpenStreetMap.


## In-app updates
Fra v0.3.7 laster WayCrew APK-en direkte fra siste GitHub Release. Android viser fortsatt den vanlige systemdialogen for å godkjenne installasjonen. Samme release-signering må brukes på alle APK-er.

## v0.3.9 – Chat Message Management

- Brukere kan slette egne chatmeldinger.
- Turleder kan moderere aktivitetschat.
- Gruppeeier og administrator kan moderere gruppechat.
- Sletting krever bekreftelse og håndheves server-side.
- Slettede meldinger vises som «Meldingen er slettet».
- Original meldingsinnhold flyttes til en låst audit-tabell før innholdet fjernes fra den synlige meldingsraden.
- Systemmeldinger kan ikke slettes.

## v0.3.8 – Scheduling, Background Tracking & Notification Refresh

Planlagte aktiviteter har eksplisitt startdato og starttid. Live-sporing er flyttet fra skjermnivå til en app-global gate og fortsetter med Android foreground location så lenge brukeren er godkjent deltaker på en aktiv/pauset aktivitet. Backend stopper deling umiddelbart når aktivitet eller deltakelse ikke lenger er gyldig. Varsler fornyer Realtime-abonnement ved JWT-rotasjon. Kjør migreringen `20260914150000_schedule_tracking_notifications.sql` før testing.
