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
- Aircraft-specific guided procedures (checklists)
- Airport information
- Flight history
- Flight Setup (Startgerät-inspired): live METAR, SimBrief OFP import,
  and optional user-gated apply of weather/route into Aerofly’s `main.mcf`
  for the next simulator launch
- Camera shake tweaks: apply forum/community CameraPilot Kf/Df (feel)
  presets into the **user** `aircraft/<code>/parameters.tmd` only
  (never Steam install). Touchdown `.wav` / SoundObject packs are out of scope.

## What FlightMate IS NOT

- Flight simulator
- ATC replacement
- Moving map clone
- Always-on / silent weather or mission rewriter (writes to `main.mcf` are
  explicit, user-triggered, and require Aerofly to be quit first)
- Autopilot
- Plugin
- A bundled third-party Electron/CLI tool (e.g. Startgerät); open-source
  clones under `Reference/` are for studying and porting algorithms only

## Architecture

SwiftUI

MVVM

Network.framework (app-level); BSD sockets for UDP telemetry receive
(Aerofly broadcasts — `NWListener` is a poor fit; see `UDPListener`)

SwiftData

Feature-first architecture

Dependency Injection

### Flight Setup write path (optional, user-gated)

`LiveWeatherService` and `SimBriefService` fetch external METAR / OFP data
for display and editing in **Flight Setup**. When the user chooses
**Apply to Aerofly**, `AeroflyMcfWriter` patches weather and/or navigation
into `main.mcf` (backup first). Aerofly must be quit; it reads the file on
the next launch. Reads remain owned by `AeroflySessionService`; writes never
go through `AeroflySessionMapper`. Algorithms were ported from fboes
Startgerät / Missionsgerät (see `THIRD_PARTY.md`).

### Two independent live sources, and their precedence

The current flight state is fed by two completely independent, asynchronous
sources, plus a bundled reference database that only ever enriches:

1. **UDP telemetry** (`TelemetryService`) — realtime, high frequency.
   Position, altitude, heading, ground speed, pitch, roll, connection
   status. Highest precedence. Once a field has been observed over UDP, it
   is never overwritten by anything else.
2. **Aerofly session** (`AeroflySessionService`, reading `main.mcf` +
   `tm.log`) — low frequency, event-driven (filesystem watch on both
   files, no polling). Aircraft, livery, departure, destination,
   on-ground flag, weather, simulated time, initial position (pre-UDP
   only), Aerofly version. Aircraft identity prefers the last
   `done loading model <code>` line in `tm.log` when it disagrees with
   `main.mcf` (sim can load a new plane before rewriting `main.mcf` —
   which otherwise leaves a stale default like `c172` / Cessna). Lower
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

### Flight History Engine (built)

`FlightHistoryEngine` (`Core/FlightHistory/`) maintains the ordered,
in-memory timeline of the current flight. Where `FlightEventEngine` only
*detects* transitions (and keeps a bounded, trimmable rolling window of
them), `FlightHistoryEngine` is the one place that owns the complete,
never-reordered, never-mutated-after-insertion story of a flight from the
moment an aircraft is loaded to the moment it's completed (or aborted).
This is **not** a replay system, **not** persistence, and **not**
SwiftData — everything lives in memory for the lifetime of the app
process; a future milestone decides if/when/how any of it gets saved.

It consumes `FlightEventEngine.eventPublisher` *only* — never raw UDP
telemetry, never `FlightContext`, never `FlightAnalysis` directly, and it
never duplicates any detection logic. `FlightEventEngine` has no knowledge
that `FlightHistoryEngine` exists; it's just another subscriber to its
already-public `eventPublisher` (deliberately *not* `events`, since that
array is bounded/trimmable — `eventPublisher` fires every event
unconditionally, which is exactly what a complete history needs).

Split, mirroring every other engine/service pair in this codebase:

- **`FlightHistory`** (`Identifiable`, `Equatable` struct) — a single
  flight's `id`, `startTime`, ordered `events: [FlightEvent]`, and
  `status` (`FlightHistoryStatus`: `.active`/`.completed`/`.aborted`).
  `currentAircraft`/`departureAirport`/`destinationAirport`/
  `durationSeconds` are all *derived*, read off the most recent event's
  `FlightAnalysis` snapshot rather than duplicated/re-tracked — one source
  of truth. Value semantics throughout: `appending(_:)` and
  `finalized(as:at:)` both return a new copy rather than mutating in
  place, so a view or consumer holding an older `FlightHistory` value
  never sees it change out from under it.
- **`FlightHistoryService`** (pure `enum`, static functions only) — given
  one `FlightEvent` and the current `State` (`currentHistory` +
  `completedHistories`), returns the next `State`. No state of its own,
  no I/O, no Combine — trivially unit testable in isolation from the
  engine.
- **`FlightHistoryEngine`** (stateful `ObservableObject`) — owns no
  transition-rule logic, only Combine wiring: subscribes to
  `flightEventEngine.eventPublisher`, threads `FlightHistoryService.State`
  across observations, and publishes `currentHistory` (`nil` until an
  aircraft is loaded) plus a bounded `completedHistories` (oldest first,
  default last 25, oldest dropped past that — mirrors
  `FlightEventEngine.events`'s own bound, for the same reason: safe for
  many flights across one long app session).

**History lifecycle rules** (see `FlightHistoryService`):

- A history begins only on `aircraftLoaded` or `aircraftChanged` — no
  other event (e.g. a stray `telemetryLost` before any aircraft is ever
  loaded) starts one. This mirrors `FlightEventDetectionService`'s own
  aircraft-identity latch semantics.
- `flightCompleted` appends the event, then finalizes the history as
  `.completed` and moves it to `completedHistories`.
- `aircraftChanged` while a history is already active is treated as a
  session boundary, not a mid-flight detail: the current history is
  finalized as `.aborted` and moved to `completedHistories`, and a new
  history is immediately started, seeded with that same `aircraftChanged`
  event as its first entry. `aircraftLoaded` while already active behaves
  identically (symmetry, since `aircraftLoaded` is otherwise a one-time,
  application-lifetime event per `FlightEventDetectionService`, so this
  path only matters defensively). There is deliberately no idle gap
  between flights.
- Any other event with no active history (e.g. `flightCompleted` firing
  with nothing to complete) is dropped rather than starting a malformed
  history.

**Construction-order requirement** — like every engine layered on a
`PassthroughSubject`-backed publisher in this codebase,
`FlightHistoryEngine` must be constructed immediately after
`FlightEventEngine`, before any telemetry/session watching starts (see
`FlightHistoryEngine`'s own doc comment). `eventPublisher` never replays
past events to a late subscriber, so this ordering — already established
for `FlightEventEngine` itself in `FlightMateApp.init()` — is what
guarantees no event is ever emitted into a gap where nothing is listening
yet.

**Why a separate layer instead of extending `FlightEventEngine`** —
`FlightEventEngine` answers "what just happened," bounded and
trim-friendly, appropriate for a detector that must stay cheap across a
multi-hour flight. `FlightHistoryEngine` answers "what has happened, in
order, for this flight" — a fundamentally different contract (complete,
ordered, immutable-once-inserted) with different future consumers
(Timeline UI, Flight Recorder, AI debrief, Flight Statistics, eventual
Logbook). Merging the two would force every future history consumer to
depend on `FlightEventEngine`'s detection internals and its trimming
behavior, and would force every future detection-only consumer to pay for
history bookkeeping it doesn't need.

**Path to persistence** — nothing here depends on staying in-memory.
`FlightHistory`/`FlightEvent` are plain, `Codable`-friendly value types
today; a future milestone can add a SwiftData-backed store that observes
`FlightHistoryEngine.$completedHistories` (and optionally
`$currentHistory`, for crash recovery) and persists each finalized
history exactly once, without `FlightHistoryEngine` itself ever knowing
persistence exists — the same "publish, let another layer decide what to
do with it" pattern `eventPublisher` already established.

**Path to replay** — a future Replay feature only needs to iterate a
`FlightHistory.events` array in order and re-render/re-narrate each
`FlightEvent`'s carried `FlightAnalysis` snapshot on a timer — it doesn't
need a separate recording format, because `FlightHistory` already *is* the
complete, ordered recording. Whether the source is today's in-memory
`completedHistories` or, later, a SwiftData-loaded history makes no
difference to a replay consumer.

Not surfaced in any production UI yet — a minimal, unstyled
`FlightHistoryDebugView` (current history's status/aircraft/route/
duration plus its event list, and a one-line summary per completed
history) is wired into the dashboard for manual verification only.
Constructed and injected once in `FlightMateApp`, immediately after
`FlightEventEngine`.

### Aircraft Asset Manager (built — abstraction only)

`AircraftAssetManager` (`Core/AircraftAssets/`) resolves aircraft preview
images for the UI through a prioritized provider chain. Views never access
the filesystem, never hardcode image names, and never know which provider
won — they request an asset via `AircraftAssetManaging.resolve(_:)` and
render the result with `AircraftAssetImage`.

**Shipping provider chain** (highest priority first):

1. `BundledAircraftAssetProvider` — FlightMate-owned per-aircraft /
   per-livery PNG/WebP under `Resources/Aircraft/Assets/` (none shipped
   yet; an empty folder is valid).
2. `CategoryPlaceholderAssetProvider` — category illustration if present,
   otherwise the category's SF Symbol stand-in.
3. `SystemSymbolAssetProvider` — generic SF Symbol; always succeeds.

**Explicitly out of scope:** decoding or redistributing Aerofly `.ttx`
textures. IPACS's format is one-way by design (copyright + compression).
Future providers (user-installed asset packs, licensed artwork, official
IPACS support) plug into `AircraftAssetProviding` without changing the
manager's public API.

In-memory resolution caching via `AircraftAssetCaching`; the protocol is
ready for a future disk-backed implementation. Wired into
`DashboardView`/`AircraftCard` today; Aircraft Browser / AI will reuse the
same manager.

Airport imagery is a separate concern — when Airport Browser lands, prefer
MapKit snapshots over bundled airport thumbnails.

### Planned future pipeline

```
Telemetry → Session → Domain Resolution → Flight Analysis → Flight Events → Flight History → Context Builder → AI
                                                                              ^^^^^^^^^^^^^^
                                                                                built ✅
```

- **Prompt Context Builder** (paused relative to procedures work): combines
  `FlightAnalysis`, `FlightEvent`(s), and `ResolvedSession` into one
  compact, structured AI context object — so the eventual AI instructor
  consumes a clean aviation summary and never sees raw telemetry.

### Guided Procedures / Aircraft Procedure Platform (Phase 1 ✅)

Data-driven **guided procedures** teach Aerofly aircraft step by step
(Duolingo-style: one action, where, why — not a PDF checklist).

- **Spec:** `Resources/Knowledge/SPEC.md` (Procedure Specification v1)
- **Content:** A320neo Cold & Dark curated from the official Aerofly
  A320 tutorial (`a320_neo.cold_and_dark.json`). Open-source MSFS/airline
  checklists are reference-only and never shipped.
- **Core:** `Core/Procedures/` — `Codable` models, `KnowledgeDataLoading`,
  `ProcedureService` / `ProcedureProviding` (constructor-injected)
- **UI:** `Features/Procedures/` — sidebar **Procedures** destination;
  aircraft → procedure → Step N of M → completion
- **Fidelity tiers** in schema: `aerofly_verified` / `family_derived` /
  `draft`; optional `inheritsProceduresFrom` for later Airbus family reuse
- **Not in Phase 1:** telemetry auto-check, panel highlight images, taxi→
  shutdown phases, multi-aircraft content, progress persistence

## Coding Rules

- Never use UIKit.
- Never use singletons.
- Never hardcode airport data.
- Never hardcode procedure / checklist content in Swift — load from Knowledge JSON.
- Keep files under 300 lines.
- Every service must be testable.
- Prefer protocol-oriented design.
- UI must not contain business logic.

always read this file before making changes.
