# WayCrew Release Notes

## v0.2.16 – GitHub CI Template Test Fix

- Fixes GitHub Actions analyzer failure caused by Flutter-generated `test/widget_test.dart` referencing the default `MyApp` template class.
- CI now removes only the generated Flutter template test after `flutter create`.
- Existing WayCrew tests remain intact and still run with `flutter test`.
- No Supabase migration in this release.

# WayCrew v0.2.15 – Place Search Fix

- Retter Photon-søk som sendte ugyldig norsk språkkode `no`.
- Bruker `nb` for norsk bokmål.
- Legger inn robust firetrinns fallback: Norge+språk, Norge uten språk, globalt+språk, globalt uten språk.
- Oppdaterer Place Search User-Agent til WayCrew v0.2.15.
- Ingen Supabase-migrering i denne versjonen.
