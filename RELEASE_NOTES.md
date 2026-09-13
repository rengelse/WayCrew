# WayCrew release notes

## v0.3.3 – Route Creation & Live Marker Fix

- Fix Android release build: `desugar_jdk_libs` upgraded to 2.1.4 for `ota_update`.
- Add `cupertino_icons` dependency required by referenced Cupertino icon data.
- Harden route creation: activity cannot be published unless route geometry has at least two points.
- Send route geometry to Supabase as explicit JSON text and parse/validate server-side.
- Live map participant labels now use activity-specific markers (MC, ski, cycling, hiking, running, kayak, climbing) with participant name/role.
- No silent fallback to empty route geometry.

# v0.3.2 – In-app APK Update

- WayCrew now downloads the APK directly inside the app instead of opening GitHub in the browser.
- Download progress is shown in-app.
- When the APK is ready, WayCrew opens Android's installer automatically.
- Added Android `REQUEST_INSTALL_PACKAGES`, internal OTA FileProvider configuration and desugaring required by the updater.
- Manual update checks in Settings use the same in-app download/install flow.
- Regular Android apps still require the user to approve the final installation prompt.
- No Supabase changes.

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
