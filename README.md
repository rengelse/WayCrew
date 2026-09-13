# WayCrew v0.2.15

Gjeldende versjon: **0.2.15+27**. Denne versjonen retter Photon-basert stedsøk/autocomplete.

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
