---
name: codexu-pr-review
description: Review codexU pull requests and decide whether they should be merged, changed, split, declined, or kept as a fork based on product positioning, roadmap, privacy, data semantics, native macOS design, architecture, scope, and verification. Use for PR review, mergeability assessment, contribution triage, and feature-fit decisions in the codexU repository.
---

# codexU PR Review

Use this skill only inside the codexU repository. Review by default; do not edit
the branch, post comments, approve, merge, or close a PR unless the user asks.

## Establish The Baseline

1. Read `AGENTS.md` completely.
2. Read the documents relevant to the diff:
   - Product: `README.md`, the matching `docs/PRD-*.md`, and `CHANGELOG.md`.
   - UI: `docs/DESIGN_SYSTEM.md`.
   - Privacy or network: `SECURITY.md`.
   - Packaging or compatibility: `DISTRIBUTION.md` and `Makefile`.
   - Contributions: `CONTRIBUTING.md`, `.github/pull_request_template.md`, and CI.
3. Inspect `git status`, the base/head relationship, the complete diff, changed
   files, commits, and test evidence. Preserve unrelated working-tree changes.
4. For a GitHub PR, inspect its current description, reviews, checks, and
   discussion with `gh` when available.
5. Separate documented requirements from roadmap inference. Do not present an
   experimental branch, open PR, or issue as an accepted commitment.

## Apply The Product North Star

codexU is a local-first, privacy-preserving, lightweight macOS menu-bar and
desktop tool for quickly judging AI coding quota, usage, trends, and task state.
Prefer changes that make those judgments more accurate, faster, quieter, or more
reliable. Treat general system monitoring, agent orchestration, remote control,
marketing surfaces, and personal workflow replacements as outside the default
product boundary.

## Review In Order

1. Check the hard gates in `references/acceptance-rubric.md`. Any unresolved
   hard-gate failure blocks merge regardless of score or CI status.
2. Verify that the user problem is concrete, frequent enough for the upstream
   product, and solved without unnecessary controls or information density.
3. Check that the implementation extends shared domain/provider/presentation
   models instead of adding provider-, palette-, or mode-specific branches.
4. Verify data semantics: official, local, fallback, estimate, missing, stale,
   and zero must remain distinguishable.
5. Verify UI consistency, accessibility, stable layout, and idle resource use.
6. Check failure paths, compatibility, migrations, documentation, and tests in
   proportion to risk.
7. Apply the weighted rubric only after the hard gates pass.

## Decide

Return exactly one primary recommendation:

- `Merge`: ready as submitted, with no unresolved blocking finding.
- `Request changes`: direction fits, but bounded fixes are required.
- `Split / RFC first`: value may fit, but scope or product architecture must be
  decided before implementation can be reviewed safely.
- `Decline / keep as fork`: the change is a customization or changes codexU into
  a materially different product.

Lead with blocking findings ordered by severity and cite files and lines. Then
state the recommendation, product/roadmap fit, validation evidence, and anything
not verified. Passing CI is necessary when configured, but never sufficient by
itself. If there are no findings, say so explicitly and identify residual risk.
