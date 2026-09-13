# WayCrew v0.3.7

Gjeldende versjon: **0.3.7+39**. WayCrew kan nå laste ned en ny signert APK direkte i appen, vise nedlastingsfremdrift og åpne Android-installasjonen automatisk når filen er klar.

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

## v0.3.7 – Live Map UX & Safety

WayCrew now includes non-overlapping live-map controls, activity-specific participant markers with privacy-reduced names, blocked-user management, reporting and support/help flows. Run the new Supabase migration before testing safety features.
