## Summary

-

## Validation

- [ ] `make build`
- [ ] Account automation self-tests when switching, Feishu, or audit behavior changes
- [ ] `make probe` only when approved and data-source behavior changes

## Privacy Check

- [ ] No private Codex thread titles, local paths, screenshots, account/auth data, or webhook URLs are included.
- [ ] Any public Windows screenshot or report uses fully synthetic fixtures; `.local-artifacts/` output is not attached or linked.

## Palette Package Contribution

Complete this section only when the PR adds or changes `Resources/Palettes/**`.

- [ ] I started from `contrib/palette-template` and did not add palette-specific Swift, scripts, binaries, fonts, CSS, or HTML.
- [ ] I described the design intent, semantic role mapping, and Light/Dark differences below.
- [ ] I documented the inspiration/source, author, MIT license, and whether the work is original or a licensed design translation.
- [ ] I checked that success, warning, error, disabled, text, Surface, font, and layout semantics remain unchanged.
- [ ] I ran `make test-palettes` and `./scripts/test-status-item.sh`.
- [ ] I attached privacy-safe Light/Dark evidence for the main window, settings, and all three menu-bar density modes.
- [ ] Patterned palettes include 0%, 1%, 35%, 73%, 93%, 99%, and 100% evidence for rings and linear progress.
- [ ] I understand that passing machine validation does not guarantee acceptance; palettes remain subject to design and accessibility review.

### Palette design and source

- Design intent:
- Semantic role mapping:
- Light/Dark strategy:
- Status-color conflict analysis:
- Source and license:
- Validation and visual evidence links:
