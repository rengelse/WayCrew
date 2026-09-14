# WayCrew production cleanup – v0.4.1

Denne oppdateringen fullfører oppryddingen etter v0.4.0.

## Fjernet permanent
- lokal demo-modus
- demo-login / «Fortsett i lokal demo»
- `ENABLE_LOCAL_DEMO`
- alle mock repositories og mock stores
- hardkodede demoaktiviteter, demogrupper, demochat, demovarsler og demohistorikk
- Dev Scenario Switcher og offline/stale/full mock-scenarier
- mock-only testfil

## Flyttet til produksjonsstruktur
- lokale brukerinnstillinger ligger nå i `lib/data/local/settings_store.dart`
- aktivitetsfilter ligger i `lib/data/local/activity_filter_store.dart`
- profilmodellene ligger i `lib/domain/models/profile_models.dart`
- felles repositories/providers ligger i `lib/data/providers.dart`

## Arkitektur etter cleanup
UI → production providers → Supabase repositories/RPC/Realtme.

Det finnes ikke lenger en alternativ mock-/demo-datakilde i appen.
