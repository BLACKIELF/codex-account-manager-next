# Community Palette Template

This directory is a controlled starting point for a codexU palette contribution. Copy it into `Resources/Palettes/<stable-id>/`, rename `manifest.id` to the same ID, and replace every example value and description.

Before submitting:

- Design Light and Dark variants independently.
- Keep status, text, Surface, font, geometry, and interaction outside the package.
- Add SVG only through the public asset slots and declare `svg-patterns` when used.
- Replace the author, source statement, localization, and LICENSE copyright holder.
- Run `make test-palettes` and `./scripts/test-status-item.sh`.
- Attach the visual evidence requested by the pull request template.

Passing validation is necessary but does not guarantee acceptance. Maintainers review accessibility, semantic clarity, visual quality, source provenance, and long-term maintenance cost.
