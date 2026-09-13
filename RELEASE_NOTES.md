# v0.3.1 – Route Planning Analyzer Fix

- Fixed `curly_braces_in_flow_control_structures` in route planning service.
- Updated mock repository tests to provide the required `routePlan` argument.
- No Supabase changes.

# WayCrew v0.3.0 – Route Planning

## Nytt
- Faktisk ruteberegning mellom start og destinasjon via Valhalla/OpenStreetMap for MC, sykkel, fottur, løping, klatring og øvrige landaktiviteter.
- Opptil seks mellomstopp/waypoints i opprettelsesflyten.
- Rute forhåndsvises på kart før publisering med beregnet distanse og tid.
- Rutegeometri, distanse, varighet, routingprofil og leverandør lagres i Supabase.
- Aktivitetssiden viser planlagt rute, start, mellomstopp og mål.
- Hovedkartet viser ruten for valgt aktivitet.
- Live-kartet viser planlagt rute under deltakernes live-posisjoner.
- Kajakk og ski bruker foreløpig manuell waypoint-geometri i stedet for feilaktig bil-/gangrouting.

## Backend
Ny migrering: `20260913220000_route_planning.sql`.

## Build
- Versjon: `0.3.0+32`
- Eksisterende signert GitHub Actions release-build beholdt.
