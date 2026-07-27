# Aircraft

`aircraft-liveries.json` is bundled here and loaded by `ReferenceDataLoader` /
`AircraftService`.

## Source

Copied as-is from [`fboes/aerofly-data`](https://github.com/fboes/aerofly-data),
file `data/aircraft-liveries.json` (44 aircraft types with performance
characteristics, each including a `liveries` array).

This replaces the plain `aircraft.json` file previously bundled here.
`aircraft-liveries.json` is a strict superset (same fields, plus liveries) —
it's also the file the source repo's own `index.js` re-exports as its
canonical aircraft dataset. `ReferenceDataLoader` decodes this single file
two ways:

- `loadAircraft() -> [Aircraft]` — the `Aircraft` model has no `liveries`
  property (kept lean), so the extra key is simply ignored by `Codable`.
- `loadAircraftLiveries() -> [AircraftLiveryGroup]` — a small DTO
  (`aeroflyCode` + `liveries`) that `AircraftService` uses to build a
  separate livery lookup, exposed via `liveries(for:)` and
  `liveries(icaoCode:)`.

`AeroflyAircraftReference.md` (also bundled here, renamed from the source's
`aircraft.md` to avoid colliding with this file at the flattened bundle
root) is the source repo's own human-readable aircraft list, kept for
reference.

`fboes/aerofly-data` is MIT licensed, Copyright © 2024 Frank Boës — see
`../Airports/LICENSE.txt` for the full text, reproduced here as required by
the license.

## Updating

Re-download `data/aircraft-liveries.json` from the repo above and replace
`aircraft-liveries.json` verbatim — no transformation needed.
