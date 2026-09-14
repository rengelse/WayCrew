# Release notes

## v0.4.1 – Demo Removal & Production-Only Data Layer
- Removed all local demo mode and demo login UI.
- Removed all mock repositories, stores, mock data and Dev Scenario tooling.
- Production providers now use Supabase only.
- Renamed persistent local settings/filter stores out of the mock namespace.
- Moved profile data types to the domain model layer.
- Removed mock-only tests and added CI audit rules that fail if demo/mock runtime code returns.
- No Supabase migration required.

# WayCrew v0.4.0 – Production Audit & Cleanup

- Full static production audit across Flutter, Supabase, routing, updater, tracking and CI.
- Release builds now default to production; local demo and Supabase debug are explicit opt-ins.
- Removed obsolete Valhalla web-frontend fallback.
- Added centralized user-facing error sanitization for critical screens.
- Added Supabase privilege-hardening migration for internal/helper functions.
- Added `tool/audit_project.py` and CI production audit guard.
- Refreshed stale project documentation and baseline references.
- New migration: `20260914194500_production_audit_cleanup.sql`.

---

# WayCrew v0.3.9 – Chat Message Management

- Added soft-delete for chat messages with explicit confirmation.
- Users can delete their own messages.
- Activity leaders can moderate activity chat; group owners/admins can moderate group chat.
- Deletion is enforced by the `delete_chat_message` Supabase RPC.
- Original message content is copied to a locked `message_delete_audit` table before the visible message body is cleared.
- Deleted messages remain in conversation order as «Meldingen er slettet».
- System messages cannot be deleted.
- New migration: `20260914193000_chat_message_management.sql`.

---

# Release notes

## v0.3.8 – Scheduling, Background Tracking & Notification Refresh

- Adds explicit activity start date and start time when planning an activity.
- Start timestamp is shown in activity cards, detail view and publish review.
- App-level live tracking gate starts/maintains foreground tracking for approved participants in active/paused activities, independent of the live-map screen.
- Server-side participant lifecycle trigger immediately disables sharing when a participant leaves, is removed, rejected or withdrawn.
- Server remains the source of truth: live positions are accepted only for approved/active participants while the activity is active/paused.
- Live tracking stops locally when the server reports that the activity ended or participation is no longer valid.
- Notification Realtime subscriptions now rebuild on Supabase JWT rotation and retry after an expired token.
- Notification error state includes a retry action.
- Adds migration `20260914150000_schedule_tracking_notifications.sql`.

## v0.3.7 – Live Map UX & Safety

- Moves the live-map group-centering control below the top action row so it no longer overlaps `Vis gruppen`.
- Live participants use activity-specific visual markers (MC, ski, cycling, hiking, running, kayak, climbing) with privacy-reduced names.
- Participant labels show first name; duplicate first names fall back to first + last initial.
- Adds functional blocked-user management backed by Supabase.
- Adds user reporting with categories, description, report history and server-side validation.
- Adds support/help with direct support email action.
- Participant sheet now allows reporting or blocking another participant.
- Adds Supabase migration `20260913224500_safety_blocking_reporting.sql`.

## v0.3.6 – Routing Transport Fix

- Robust Valhalla transport: POST first, automatic GET `?json=` retry on HTTP 405.
- Fallback between public Valhalla demo endpoints.
- Keeps polyline6 route geometry decoding.
- Routing failures now include useful HTTP/server diagnostics instead of a generic message.
- No Supabase migration in this release.

# WayCrew v0.3.5 – Routing API Host Fix

- Fixed Valhalla routing API host: requests now use `https://valhalla1.openstreetmap.de/route`.
- Route responses explicitly request `polyline6`, matching the decoder already used by WayCrew.
- Routing failures now include HTTP status and available API error detail.
- No Supabase migration in this release.

# WayCrew v0.3.4 – Route Geometry Decode Fix

- Fixed Valhalla route parsing: supports encoded polyline6 as well as GeoJSON shapes.
- Switched routing endpoint to the canonical `valhalla.openstreetmap.de`.
- Empty optional waypoint rows no longer block route calculation or publishing.
- No Supabase migration in this release.

---

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
