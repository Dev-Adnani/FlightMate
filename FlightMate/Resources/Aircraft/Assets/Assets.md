# FlightMate Aircraft Assets

FlightMate-owned preview images for the Aircraft Asset Manager.

**Do not place Aerofly `.ttx` files here.** IPACS’s texture format is
one-way by design; FlightMate will not reverse-engineer or redistribute
copyrighted Aerofly artwork. See the Aircraft Asset Manager milestone
research notes.

## Layout

Xcode’s file-system synchronized groups flatten resource subdirectories at
build time, so resource *names* (not folder paths) are what
`BundledAircraftAssetProvider` / `CategoryPlaceholderAssetProvider` look
up. Keep files in this folder for organization; name them as follows:

| Kind | Resource name (no extension) | Example file |
| --- | --- | --- |
| Per-aircraft preview | `{aeroflyCode}` | `a320_neo.png` |
| Per-livery preview (optional) | `{aeroflyCode}-{liveryCode}` | `a320_neo-lufthansa.png` |
| Category illustration | `category-{AircraftCategory.rawValue}` | `category-airliner.png` |

Supported extensions: `.png`, `.webp`, `.jpg`, `.jpeg`.

## Resolution order

`AircraftAssetManager` tries, in order:

1. Per-livery bundled image (if a livery code was requested)
2. Per-aircraft bundled image
3. Category illustration (bundled), else category SF Symbol
4. Generic SF Symbol (`airplane.circle.fill`)

An empty Assets folder is valid — every request falls through to category /
SF Symbol placeholders. Drop files here later (commissioned art, CC
silhouettes, user-installable packs via a future provider) without changing
call sites.

## Category `rawValue`s

`airliner`, `generalAviation`, `military`, `historical`, `helicopter`,
`aerobatic`, `glider`.

## Current shipping state

No per-aircraft or category raster images are shipped yet. The manager
returns category SF Symbols (when category is known) or the generic SF
Symbol fallback. Artwork is a polish milestone, not a product blocker.
