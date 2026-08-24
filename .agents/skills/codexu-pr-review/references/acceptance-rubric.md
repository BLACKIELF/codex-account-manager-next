# codexU PR Acceptance Rubric

Use this rubric after reading the current repository documents and the complete
change. Written project rules override this reference when they differ.

## Hard Gates

An unresolved item below blocks merge:

- Product boundary: the PR replaces a supported core workflow, turns codexU into
  a general dashboard/control center, or mainly serves a private customization.
- Privacy: it uploads or exposes usage, transcript, task, thread, account, path,
  prompt, response, tool argument, tool output, auth, environment, or raw logs.
- Security: it stores secrets outside an appropriate secure store, broadens
  network/file access without explicit scope and opt-in, executes contributed
  content, or weakens update/package integrity.
- Data truth: it presents estimates as official, missing/stale/error as zero,
  transport slots as fixed business semantics, or mixed-runtime data as a
  single-runtime fact.
- Regression: it removes a supported runtime or behavior, overwrites user state,
  lacks rollback on failure, or silently changes installation/update behavior.
- Supply chain: it adds generated build artifacts, unsafe executable resources,
  unclear licensing/provenance, or an unjustified dependency.

## Weighted Review

| Dimension | Points | Full-credit standard |
| --- | ---: | --- |
| Product and roadmap fit | 20 | Strengthens quota, usage, trends, tasks, native interaction, compatibility, reliability, or controlled extensibility. |
| User value | 15 | Solves a specific upstream problem with clear frequency and a smaller cognitive/interaction cost. |
| Privacy and security | 15 | Preserves local-first behavior, minimizes data, scopes access, protects secrets, and uses privacy-safe evidence. |
| Data correctness | 15 | Models source, window, runtime, estimate, fallback, missing, stale, error, and zero honestly. |
| Architecture and maintenance | 10 | Reuses shared domain/provider/presentation patterns and reduces total long-term complexity. |
| Native UX, accessibility, performance | 10 | Follows the design system, remains readable and stable, supports accessibility, and stays quiet when idle. |
| Verification | 10 | Covers normal and failure paths with targeted tests, builds, probes, visual checks, and compatibility evidence. |
| Scope, documentation, release discipline | 5 | One reviewable concern, current base, required docs updated, no generated/release-only noise. |

Interpretation, only when all hard gates pass:

- 80–100: merge candidate.
- 70–79: request changes.
- Below 70: split, redesign, RFC, or decline.

The score supports judgment; it does not replace specific findings.

## Product And Roadmap Questions

- Can the user complete a core judgment faster or with more confidence?
- Is this broadly useful to codexU users rather than one environment?
- Does it extend an accepted model, or does it introduce a parallel product?
- Is the roadmap support explicit in stable documents, or only inferred from an
  issue, PR, branch, or commit sequence?
- Could the useful generic part be split from customization?

High-fit work usually includes parser/protocol correctness, quota compatibility,
resource fixes, macOS compatibility, focused native interactions, multi-runtime
attribution, and controlled declarative palettes.

Low-fit work usually includes general system health dashboards, agent control,
remote workflow management, replacing one supported runtime with another,
marketing content, or large personal distributions.

## Data Review

Check at least:

- Official vs local detailed vs local fallback vs estimate.
- Missing vs unsupported vs stale vs loading vs error vs real zero.
- Window duration and identity instead of `primary`/`secondary` slot position.
- Counter resets, repeated cumulative snapshots, partial responses, and ordering.
- Time zone, day/month boundary, archived history, and large local datasets.
- Runtime/provider attribution and aggregation boundaries.
- User-facing model names: do not store monthly semantics in a seven-day model
  merely because the existing UI has a secondary slot.

## UI And Resource Review

Check Light, Dark, high contrast, long Chinese/English content, VoiceOver,
tooltips, keyboard interaction, truncation, empty/loading/error states, and
layout stability during refresh. Color must not be the only information channel.

Continuous animation, polling, parsing, and rendering must stop or reduce when
the window is hidden, minimized, obscured, unfocused, on another desktop, under
thermal/low-power pressure, or when reduced motion applies. Decoration must not
increase background cost or become necessary to read data.

Palette changes must remain declarative and inside the public token contract.
They must not override fixed Surface, Text, Control, Motion, Status, font, or
layout semantics, and must include provenance, license, localization, validation,
and privacy-safe visual evidence.

## Architecture And Scope Review

- Prefer Domain/Provider/Service/Presentation/UI separation already present.
- Views consume normalized models; they do not parse source JSON or branch on a
  palette ID/provider when a shared model can express the behavior.
- Add abstractions only when they reduce total complexity.
- Avoid combining a runtime change, system feature, UI redesign, performance
  rewrite, branding edit, and release work in one PR.
- Do not bump versions or edit released notes during ordinary feature work.
- Preserve contributor attribution while rebasing or completing maintainer fixes.

Recommend splitting when independently valuable pieces can ship or be rejected
separately, especially generic fixes embedded in a product fork.

## Verification Matrix

| Change | Expected evidence |
| --- | --- |
| Any code | `make build`, `git diff --check` |
| Data reader/aggregation | `make probe` or `--dump-json`, synthetic fixtures, failure-path self-tests |
| Rate limits/windows | rate-limit self-tests covering single, multiple, reordered, duplicate, unknown, missing, and stale cases |
| UI | local app inspection, Light/Dark evidence, long localization, accessibility and refresh stability |
| Status item | status-item presentation/rendering tests and real menu-bar inspection |
| Palette | `make test-palettes`, status-item tests, required progress states and Light/Dark screenshots |
| Performance | before/after measurements and idle/hidden-window behavior |
| Compatibility | relevant SDK/compiler/architecture targets and fallback path |
| Packaging/update | package checks, signature, architecture, checksum, mount and explicit non-notarized status when applicable |
| Documentation only | `git diff --check` |

The PR description should state what changed, why, user impact, privacy/network
impact, migration or compatibility impact, exact validation, screenshots when
visual, and what was not verified.
