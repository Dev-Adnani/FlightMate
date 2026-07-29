# FlightMate Procedure Specification v1

**Version:** 1.0.0

Guided procedures teach Aerofly FS 4 aircraft systems step by step.
Swift contains no aircraft-specific procedure text — only loaders and UI.

## Bundle layout

```
Knowledge/
  schema_version.json
  SPEC.md
  procedure_aircraft_index.json   # ["a320_neo", ...]
  Aircraft/
    a320_neo/
      a320_neo.aircraft.json
      procedures/
        a320_neo.cold_and_dark.json
  Panels/     # reserved (panel images + highlight areas)
  Shared/     # reserved (glossary, systems)
```

### Resource naming (required)

Xcode flattens resource subdirectories at build time. Every JSON
resource must have a **globally unique basename**:

| Resource | Bundle name |
|----------|-------------|
| Aircraft metadata | `{aircraftId}.aircraft.json` |
| Procedure | `{aircraftId}.{procedureId}.json` |
| Index | `procedure_aircraft_index.json` |

## Object model

`Aircraft` → `Procedure` → `Section` → `Step` → `Location` / `Verification`

### Aircraft (`{id}.aircraft.json`)

| Field | Type | Notes |
|-------|------|--------|
| `id` | string | Aerofly code (`a320_neo`) |
| `name` | string | Display name |
| `manufacturer` | string | |
| `family` | string | e.g. `airbus_fb` |
| `category` | string | e.g. `airliner` |
| `supportedProcedures` | string[] | Procedure ids |
| `fidelity` | string | See fidelity tiers |
| `inheritsProceduresFrom` | string? | Optional parent aircraft id (Tier B) |

### Procedure (`{aircraftId}.{procedureId}.json`)

| Field | Type | Notes |
|-------|------|--------|
| `id` | string | e.g. `cold_and_dark` |
| `title` | string | |
| `aircraft` | string | Owning aircraft id |
| `version` | int | Content revision |
| `estimatedMinutes` | int | |
| `difficulty` | string | `beginner` / `intermediate` / `advanced` |
| `fidelity` | string | See fidelity tiers |
| `disclaimer` | string | Always include sim-only disclaimer |
| `sources` | object[] | `{ "title", "url"? }` |
| `sections` | Section[] | Ordered; steps inline |

### Section

| Field | Type |
|-------|------|
| `id` | string |
| `title` | string |
| `order` | int |
| `optional` | bool? |
| `steps` | Step[] |

### Step

| Field | Required | Notes |
|-------|----------|--------|
| `id` | yes | Stable within procedure |
| `order` | yes | Within section |
| `title` | yes | Short label |
| `instruction` | yes | What to do |
| `purpose` | yes | Why it matters |
| `location` | yes | `{ panel, section, hint }` |
| `expectedResult` | yes | string[] |
| `verification` | yes | `{ "mode": "manual" }` (v1) |
| `condition` | no | e.g. only if EXT PWR AVAIL |
| `caution` | no | |
| `notes` | no | string[] |
| `estimatedSeconds` | no | |
| `difficulty` | no | |
| `highlight` | no | Future panel area id |
| `references` | no | Shared system ids (future) |

### Verification (forward-compatible)

Today: `{ "mode": "manual" }`

Later: `{ "mode": "automatic", "telemetry": { ... } }` — no schema break.

## Fidelity tiers

| Value | Meaning |
|-------|---------|
| `aerofly_verified` | Curated from official Aerofly docs and/or verified in-sim |
| `family_derived` | Inherited from a sibling via `inheritsProceduresFrom` |
| `draft` | Authoring in progress — not ready as primary teaching path |

## Content rules

- Official Aerofly tutorials are the best primary source (Tier A).
- Open-source MSFS/airline checklists are outline references only — never ship GPL checklist JSON.
- Omit switches Aerofly does not model.
- Every step needs `purpose` and `location`.
- Procedures are for Aerofly FS learning only — not real-world flight.
