# Airports

`airports.geojson` is bundled here and loaded by `ReferenceDataLoader` /
`AirportService`.

## Source

Copied byte-for-byte from [`fboes/aerofly-data`](https://github.com/fboes/aerofly-data),
file `data/airports.geojson` (9,871 airports). Underlying geo data
originates from [OurAirports](https://ourairports.com/) (public domain).

This was chosen over the smaller `airport-coordinates(-object).json` /
`airport-list.json` files in the same repo: those only include airports the
maintainer could match against OurAirports' external database (9,230
entries). `airports.geojson` is scanned directly from Aerofly's own
scenery data, so it also includes ~640 unmatched `private_airfield`
entries (see the source repo's `data/airports-unmatched.md`) that are
missing from every other file. It's also the only file with `elevation`,
airfield `type`, and `municipality`.

`fboes/aerofly-data` is MIT licensed, Copyright © 2024 Frank Boës — see
`LICENSE.txt` for the full text, reproduced here as required by the license.

## Not included

This source does not provide runway-level detail (headings, lengths,
surfaces), so `Airport.runways` is always empty today. The `Runway` model
exists so this can be populated from a future data source without changing
`AirportService`'s API.

## Updating

Re-download `data/airports.geojson` from the repo above and replace
`airports.geojson` verbatim — no transformation needed. `Airport` decodes
each GeoJSON `Feature` directly (`geometry.coordinates` for lat/lon,
`properties.title`/`description`/`elevation`/`municipality`/`type`).

## Also bundled here (reference only, not parsed by the app)

- `airports-unmatched.md` — the source repo's own list of ICAO codes it
  could not match against OurAirports.
- `airports-custom.md` — community-contributed airport codes from
  third-party scenery packs. **Not fully covered by `airports.geojson`**:
  77 of the ~1,168 codes listed here have no coordinate data anywhere in
  the source repo (the maintainer doesn't have those add-ons installed, so
  they were never scanned into the geojson). These 77 are not usable for
  `nearestAirport`/lookup until a coordinate source is found — decided to
  leave them out of `AirportService` entirely rather than bundle unusable
  entries.
- `Icons/` — 14 SVG airfield/navaid marker icons from the source repo
  (based on Maki icons, CC0 1.0), bundled for a future Airport UI to badge
  airport types (`af-large_airport.svg`, `af-heliport.svg`,
  `navaid-vor.svg`, etc.). Not wired into any view yet — see
  `Icons/AirportIcons.md` for the full list.
