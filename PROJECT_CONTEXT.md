# FlightMate

## Purpose

FlightMate is a native macOS companion for Aerofly FS 4.

It connects to Aerofly using UDP telemetry.

The app understands the current flight and provides AI-powered contextual assistance.

## Primary Goal

Help users learn aviation and improve their flight simulation experience.

## What FlightMate IS

- Live telemetry dashboard
- AI instructor
- Flight phase detection
- Aircraft-specific checklists
- Airport information
- Flight history

## What FlightMate IS NOT

- Flight simulator
- ATC replacement
- Moving map clone
- Weather injector
- Autopilot
- Plugin

## Architecture

SwiftUI

MVVM

Network.framework

SwiftData

Feature-first architecture

Dependency Injection

### Two independent live sources, and their precedence

The current flight state is fed by two completely independent, asynchronous
sources, plus a bundled reference database that only ever enriches:

1. **UDP telemetry** (`TelemetryService`) — realtime, high frequency.
   Position, altitude, heading, ground speed, pitch, roll, connection
   status. Highest precedence. Once a field has been observed over UDP, it
   is never overwritten by anything else.
2. **Aerofly session** (`AeroflySessionService`, reading `main.mcf`) — low
   frequency, event-driven (filesystem watch, no polling). Aircraft,
   livery, departure, destination, on-ground flag, weather, simulated
   time, initial position (pre-UDP only), Aerofly version. Lower
   precedence than UDP.
3. **Bundled reference database** (`AirportService`/`AircraftService`) —
   lowest precedence, enrichment only (raw codes → full domain models).
   Never a primary source for anything.

`FlightContext` documents this precedence field-by-field in its own doc
header and enforces it in code (see `bestKnownPosition`). `TelemetryService`
and `AeroflySessionService` never read each other's data sources directly —
`FlightContextEngine` is the only place they're merged.

### Domain Resolution layer (built)

`DomainResolutionService` (`Core/DomainResolution/`) resolves the raw
Aerofly codes carried by `AeroflySession` — aircraft code, livery code,
departure/destination airport ICAOs — into full domain models
(`ResolvedAircraft`, `ResolvedAirport`, composed together as
`ResolvedSession`), by composing `AircraftService`/`AirportService` rather
than duplicating their loading logic. Named "Domain Resolution," not
"Reference Resolution": it's expected to grow beyond airports/aircraft into
airlines, navaids, procedures, frequencies, and weather presets.

Every resolution result carries a `DomainResolutionStatus`
(`.resolved`/`.partial`/`.unresolved`) instead of being merely present-or-
absent, plus a full `DomainResolutionReport` (mirrors
`AeroflySessionValidationReport`) describing exactly what did and didn't
resolve, field by field.

`country` and `runway` intentionally resolve to `nil` today — surfaced in
the report as `.unavailable` (informational), not `.missing` (a warning) —
because no country or runway dataset is bundled yet, and none is inferred
(e.g. no ICAO-prefix heuristics for country, even though the ICAO region-
prefix scheme is standardized). Adding either later only requires a new,
dedicated bundled dataset plus, for country, swapping `CountryResolving`'s
default `UnavailableCountryResolver` implementation — `ResolvedAirport`'s
shape and every call site stay unchanged.

Not wired into `FlightContextEngine`, `FlightContext`, or any UI yet — this
layer is a capability the next milestone (Flight Analysis) consumes.

### Planned future pipeline (not yet built)

```
Telemetry → Session → Domain Resolution → Flight Analysis → Event Engine → AI
```

- **Flight Analysis Engine** (next): consumes `ResolvedSession` (rich
  domain objects, never raw codes) plus live telemetry to answer "what
  phase of flight is this," "where am I," "what should happen next."
- **Event Engine** (after that): emits discrete meaningful events
  ("Aircraft loaded," "Takeoff detected," "Reached cruise," "Landed")
  instead of consumers polling flight state, so UI/recorder/notifications/AI
  react to events rather than scattering flight-state logic around the app.

## Coding Rules

- Never use UIKit.
- Never use singletons.
- Never hardcode airport data.
- Keep files under 300 lines.
- Every service must be testable.
- Prefer protocol-oriented design.
- UI must not contain business logic.

always read this file before making changes.
