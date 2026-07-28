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
`telemetryHealth`, an `AnalysisConfidence` (level + reasons), and —
consumed by the Flight Event Engine below — `resolvedAircraft`/
`resolvedDeparture`/`resolvedDestination` (the session's aircraft/route,
fully resolved). No UI consumes it yet — it exists for `FlightEventEngine`
and, eventually, the AI instructor to build on. Never invents data:
anything that can't be derived from what the simulator actually reports is
`nil`/`.unknown` rather than guessed.

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

### Flight Event Engine (built)

`FlightEventEngine` (`Core/FlightEvents/`) converts continuous
`FlightAnalysis` state into discrete, one-shot `FlightEvent`s — "the
aircraft just entered cruise," not "the aircraft is currently in cruise."
It consumes `FlightAnalysisEngine.$analysis` *only*: never raw telemetry,
never `main.mcf`, never `FlightContext`, and it never duplicates any of
`FlightAnalysisService`'s phase-detection logic — it only watches
`FlightAnalysis`'s already-published values for changes over time.

Split, mirroring the `FlightAnalysisEngine`/`FlightAnalysisService` split:

- **`FlightEventDetectionService`** (pure `enum`) — given the previous and
  current `FlightAnalysis` plus a small carried-forward `DetectionState`
  (an aircraft-identity latch, a telemetry-loss latch, an
  airborne-this-session latch), returns every event that transition
  produced (zero, one, or several) and the updated state. No state of its
  own, no I/O — trivially unit testable.
- **`FlightEventEngine`** (stateful `ObservableObject`) — owns no
  interpretation logic, only Combine wiring: subscribes to
  `flightAnalysisEngine.$analysis`, threads `DetectionState` across
  observations, and turns each detected event into a `FlightEvent`
  (`UUID`, timestamp, severity, the full `FlightAnalysis` snapshot).

**Initial event set** (11 cases, see `FlightEventType`): `aircraftLoaded`,
`aircraftChanged`, `enteredTaxi`, `takeoffDetected`, `enteredCruise`,
`enteredDescent`, `enteredApproach`, `landingDetected`, `flightCompleted`,
`telemetryLost`, `telemetryRecovered`. Naming convention: phases the
aircraft *dwells in* use `entered*` (so a future `exited*` counterpart
reads naturally); genuinely momentary occurrences keep a plain name.

**Duplicate prevention** — every rule is transition-based (`previous` vs.
`current`), never level-based, so an event fires exactly once per
transition:

- 6 of the 11 events are driven by one static `[FlightPhase:
  FlightEventType]` map — entering a mapped phase from any other phase
  fires the mapped event once. Adding a future phase-entry event is a
  one-line map addition.
- `aircraftLoaded`/`aircraftChanged` compare aircraft *codes*, not full
  `ResolvedAircraft` equality, and tolerate a transient `nil` (a `main.mcf`
  re-parse momentarily lacking a selection) without emitting anything or
  clearing the last-known aircraft — mirrors `SessionMetricsTracker`'s
  existing transient-nil tolerance.
- `flightCompleted` fires only when `flightPhase` reaches `.parked` *and*
  the aircraft was airborne (`FlightPhase.isAirborne`, the same shared
  property `FlightAnalysisService+Phase`'s takeoff guard uses) at some
  point since the last completion, via a one-shot latch that resets once
  consumed — so taxiing, a touch-and-go, or a short ground stop never
  falsely report a completed flight.
- `telemetryRecovered` only fires after a genuine `telemetryLost`, not on
  the very first `.acquiring → .live` connection at startup (which has
  nothing to "recover" from).

**History vs. publisher** — `FlightEventEngine` is a detector, not a
permanent store. `events: [FlightEvent]` is a *bounded* rolling history
(newest last, default last 500, oldest dropped past that), safe for
multi-hour sessions. `eventPublisher: AnyPublisher<FlightEvent, Never>`
fires every event immediately and unconditionally, regardless of the
history bound — the hook a future Flight Recorder subscribes to for
permanent persistence.

**Severity** — every `FlightEvent` carries a `FlightEventSeverity`
(`.info`/`.warning`/`.critical`) via `FlightEventType.defaultSeverity`.
Every event today is `.info`, even ones that could later warrant
`.warning` (e.g. `telemetryLost`) — reclassifying an existing event is a
one-line change in that single `switch` whenever a future milestone
actually introduces a severity-driven consumer (notifications, AI tone).

Not surfaced in any UI yet — constructed and injected once in
`FlightMateApp`, alongside `FlightAnalysisEngine`.

### Planned future pipeline

```
Telemetry → Session → Domain Resolution → Flight Analysis → Flight Events → Context Builder → AI
                                                              ^^^^^^^^^^^^^
                                                                built ✅
```

- **Prompt Context Builder** (next): combines `FlightAnalysis`,
  `FlightEvent`(s), and `ResolvedSession` into one compact, structured AI
  context object (aircraft/livery/phase/departure/destination/nearest
  airport/distance remaining/recent events) — so the eventual AI
  instructor consumes a clean aviation summary and never sees raw
  telemetry or has to reconstruct flight state itself.

## Coding Rules

- Never use UIKit.
- Never use singletons.
- Never hardcode airport data.
- Keep files under 300 lines.
- Every service must be testable.
- Prefer protocol-oriented design.
- UI must not contain business logic.

always read this file before making changes.
