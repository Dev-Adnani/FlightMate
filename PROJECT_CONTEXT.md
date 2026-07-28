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

Not wired into `FlightContextEngine` or `FlightContext` — those stay raw/
UDP-and-`main.mcf`-only. `FlightAnalysisEngine` (below) is the sole
consumer, calling `domainResolver.resolve(_:)` itself on every context
observation. Still not surfaced in any UI yet.

### Flight Analysis Engine (built)

`FlightAnalysisEngine` (`Core/FlightAnalysis/`) is the single source of
aviation knowledge for derived flight state. It observes
`FlightContextEngine.$context`, resolves the current `AeroflySession` via
`DomainResolutionService`, looks up the nearest bundled airport via
`AirportService`, feeds every observation to a `SessionMetricsTracker`, and
publishes the result as `FlightAnalysis` — `flightPhase` (with
human-readable `phaseReasons`), `isClimbing`/`isDescending`/`isTurning`,
`estimatedVerticalSpeedFeetPerMinute`, `estimatedGroundTrackDegreesTrue`,
cumulative `estimatedSessionDistanceNauticalMiles`/
`estimatedSessionDurationSeconds`, `nearestAirport` (a `ResolvedAirport`,
never a bare `Airport`), `distanceToNearestAirportNauticalMiles`,
`telemetryHealth`, and an `AnalysisConfidence` (level + reasons). No UI
consumes it yet — it exists for the next milestone (Event Engine) and,
eventually, the AI instructor to build on. Never invents data: anything
that can't be derived from what the simulator actually reports is `nil`/
`.unknown` rather than guessed.

Split, per file, into:

- **`FlightAnalysisService`** (pure `enum`, static functions only) —
  turns one `FlightContext` observation (plus the previous context/
  analysis, resolved session, nearest airport, and session metrics) into a
  new `FlightAnalysis`. No state, no timers, no I/O — trivially unit
  testable in isolation from the engine.
- **`FlightAnalysisService+Phase`** — the flight-phase state machine
  (`determinePhase`), kept in its own file to respect the 300-line rule.
  Order of checks matters: `landing` (hysteresis) → `parked` → `taxi` →
  `climb` → `takeoff` → `cruise` → `descent`/`approach` → unchanged
  fallback. `takeoff` is checked *before* `cruise` so a fast, level ground
  roll with an unresolved aircraft (cruise altitude unknown) is never
  misclassified as cruise.
- **`FlightPerformanceProfile`** — aircraft-specific performance numbers
  (cruise speed, approach airspeed, cruise altitude) used as phase
  thresholds when the aircraft is resolved, falling back to generic
  heuristics (`FlightAnalysisConstants`) when it isn't. Deliberately
  separate from `FlightAnalysisConstants`, which holds only generic,
  non-aircraft-specific tuning constants (parked/taxi speed bounds,
  vertical-speed deadband, turn-rate threshold, noise floors, etc.) that
  every aircraft shares.
- **`SessionMetricsTracker`** (`SessionMetricsTracking` protocol) — owns
  cumulative session distance/duration bookkeeping independently of the
  engine, so it's swappable/fakeable in tests. Resets when the resolved
  aircraft or departure airport's *identity* changes (not on a merely
  transient `nil`, since a field can be briefly unknown between session
  updates without that meaning a new flight).
- **`AnalysisConfidence`** — a `.high`/`.low` level plus the specific
  reasons behind it (e.g. "Aircraft resolved," "Nearest airport known,"
  "Fresh telemetry," "Telemetry stale"). Every core factor contributes its
  own reason regardless of overall level, so callers can check "is the
  aircraft resolved?" directly off the reasons rather than inferring it
  from the level.

`FlightAnalysisEngine` itself is a thin, stateful orchestrator: it owns no
interpretation logic, only wiring (Combine subscription, dependency
injection, carrying `previousContext`/`previousAnalysis` forward). It's
constructed and injected once in `FlightMateApp`, alongside
`FlightContextEngine`.

### Planned future pipeline

```
Telemetry → Session → Domain Resolution → Flight Analysis → Event Engine → AI
                                            ^^^^^^^^^^^^^^
                                              built ✅
```

- **Event Engine** (next): emits discrete meaningful events ("Aircraft
  loaded," "Takeoff detected," "Reached cruise," "Landed") derived from
  `FlightAnalysis` transitions, instead of consumers polling flight state,
  so UI/recorder/notifications/AI react to events rather than scattering
  flight-state logic around the app.

## Coding Rules

- Never use UIKit.
- Never use singletons.
- Never hardcode airport data.
- Keep files under 300 lines.
- Every service must be testable.
- Prefer protocol-oriented design.
- UI must not contain business logic.

always read this file before making changes.
