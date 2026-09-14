# WayCrew

## Gjeldende versjon
`0.4.3+45`

WayCrew er en Flutter-app for live gruppeaktiviteter, ruteplanlegging, grupper, chat, varsler og live tracking.

## Backend
Produksjonsdata kommer fra Supabase. Appen har ingen lokal demo-/mock-datakilde.

## Standard kontroll
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Miljø
Release bygger production som standard. Supabase URL/publishable key kan overstyres med dart-defines ved behov. Ingen service-role key skal ligge i klienten.
