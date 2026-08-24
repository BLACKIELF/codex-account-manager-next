# Palette Package v1

codexU palettes are reviewed, built-in resource plugins. Adding a directory that satisfies this contract is enough for the app to discover it and expose it in General settings; no Swift registration is required.

Start a contribution with the repository template:

```sh
cp -R contrib/palette-template Resources/Palettes/community.example
```

Rename the destination and `manifest.id` to the same stable ID, then edit both token variants and localization metadata. This is a repository contribution workflow, not a user-side theme installer.

## Package layout

```text
Resources/Palettes/<palette-id>/
├── manifest.json
├── tokens/light.json
├── tokens/dark.json
├── assets/manifest.json
├── assets/light/*.svg       # optional
├── assets/dark/*.svg        # optional
├── localizations/zh-Hans.json
├── localizations/en.json
├── README.md
└── LICENSE
```

The directory and `manifest.id` must match `^[a-z0-9]+(?:[.-][a-z0-9]+)*$`. IDs and package versions are stable compatibility identities, not display names.

## Manifest

Required v1 fields are `schemaVersion`, `id`, `version`, `minimumAppVersion`, `lifecycle`, `defaultLocale`, `localizations`, `variants`, `assetManifest`, `author`, `license`, `source`, and `capabilities`.

```json
{
  "schemaVersion": 1,
  "id": "community.example",
  "version": "1.0.0",
  "minimumAppVersion": "1.0.5",
  "lifecycle": "stable",
  "defaultLocale": "zh-Hans",
  "localizations": {
    "zh-Hans": "localizations/zh-Hans.json",
    "en": "localizations/en.json"
  },
  "variants": {
    "light": "tokens/light.json",
    "dark": "tokens/dark.json"
  },
  "assetManifest": "assets/manifest.json",
  "author": { "name": "Contributor", "url": "https://example.com" },
  "license": "MIT",
  "source": { "type": "original", "note": "Original digital palette." },
  "capabilities": ["color-tokens"]
}
```

Production builds load `stable` packages. v1 accepts only three-part versions, HTTPS author URLs, MIT-licensed built-ins, and the capabilities `color-tokens`, `svg-patterns`, and `lod-assets`.

`deprecated` packages remain resolvable only for an existing saved selection and are not offered to new users. `experimental` packages are available only to explicit development self-tests.

## Configurable tokens

Both `tokens/light.json` and `tokens/dark.json` must independently provide:

- `accent`: primary, strong/light variants, secondary variants, highlight.
- `quota.primary` and `quota.secondary`: start, end, track, label.
- `data`: 3 series colors; input/cached/output colors; 5 heatmap colors; zero; 3 value-progress and 3 milestone colors.
- `selection`: foreground, fill, stroke, focus ring.
- `surfaceTint`: color and `maximumOpacity` in `0...0.12`.
- `ornament`: ink, soft ink, secondary ink, highlight, metal.

Colors must be `#RRGGBB` or `#RRGGBBAA` sRGB. Status, window/card surfaces, text hierarchy, neutral controls, and motion are deliberately not configurable.

Quota roles are semantic rather than geometric: 5h always uses `quota.primary`, and 7d always uses `quota.secondary`, including single-window layouts. Palette Package v1 has no dedicated monthly role. Monthly falls back to `quota.secondary` by default; for a `7d + monthly` response without 5h, monthly uses the otherwise unused `quota.primary` while 7d remains `quota.secondary`.

Use `Resources/Palettes/codexu.default/tokens/light.json` as the field-complete reference. Do not remove fields merely because the two variants share a value.

## SVG assets

`assets/manifest.json` has version `1` and optional entries for:

| Slot | Render mode | Use |
| --- | --- | --- |
| `quota.ring.primary` | `fullRing` | 5h ring artwork; monthly fallback only beside 7d |
| `quota.ring.secondary` | `fullRing` | 7d ring artwork; default monthly fallback |
| `quota.cap.primary` | `fixed` | 5h endpoint; monthly fallback only beside 7d |
| `quota.cap.secondary` | `fixed` | 7d endpoint; default monthly fallback |
| `progress.linear` | `tileX` | main linear progress |
| `chart.bar` | `tileY` | daily token columns |

Each entry also declares `appearance` (`light`/`dark`), `lod` (`l0`/`l1`/`l2`), a relative `path`, and a semantic `fallback`. Missing optional slots fall back to Token rendering; declared but missing or undecodable assets invalidate the package.

SVGs are static data. Scripts, animation, text/fonts, images, foreign objects, event handlers, external/data/file URLs, DOCTYPE/entities, absolute paths, `..`, and symlinks are rejected. A file is limited to 512 KiB, 4096 elements, depth 32, and 32 filter primitives; the whole package is limited to 4 MiB.

The entire package is whitelist validated. Root files are limited to `manifest.json`, `README.md`, and `LICENSE`; Token JSON belongs in `tokens/`, localization JSON in `localizations/`, the asset index at `assets/manifest.json`, and optional SVG files under `assets/light`, `assets/dark`, or `assets/shared`. `README.md` and `LICENSE` must be present and non-empty. Hidden, unknown, executable, linked, or out-of-layout files invalidate the whole package.

Ring assets contain a complete transparent ring and no baked percentage. codexU applies the progress mask and positions caps. The primary and secondary rings must remain visually distinct rather than scaling one texture for both roles.

## Review checklist

1. Run `make test-palettes` and `./scripts/test-status-item.sh`.
2. Inspect Light and Dark variants at 1× and 2× in the fixed 820 × 720 app window.
3. Check 0%, 1%, 35%, 73%, 93%, 99%, and 100% ring progress, including single 7d, single monthly, 5h + monthly, and 7d + monthly topology.
4. Verify data hierarchy, text contrast, cultural/design attribution, and that decoration does not change layout.
5. Attach Light/Dark screenshots to the PR. The maintainers may decline visually inconsistent packages even when schema validation passes.
6. Complete the palette section in `.github/pull_request_template.md`, including source, license, status-conflict analysis, and visual evidence links.
