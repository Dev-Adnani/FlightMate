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

### Planned future pipeline (not yet built)

```
Telemetry → Session → Reference Resolution → Flight Analysis → Event Engine → AI
```

- **Reference Resolution** (next): resolves raw Aerofly codes inside
  `AeroflySession` (aircraft code, livery code, airport ICAOs) into full
  domain models via `AircraftService`/`AirportService`, so downstream
  consumers never deal with raw codes.
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
