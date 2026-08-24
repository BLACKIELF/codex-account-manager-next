# Windows public documentation boundary

The public Next repository intentionally excludes inherited Windows runtime screenshots, native-capture reports, showcase pages, and machine-specific research output. Those historical files contained real local usage totals, estimated costs, thread counts, project names, local paths, or event identifiers and are not valid public fixtures or proof of the current Next build.

Current public references:

- [`../../windows/README.md`](../../windows/README.md) — Windows workspace and verification entry point.
- [`../../DISTRIBUTION.md`](../../DISTRIBUTION.md) — packaging and cross-platform release boundary.
- [`WINDOWS_NATIVE_VISUAL_WORKFLOW.md`](WINDOWS_NATIVE_VISUAL_WORKFLOW.md) — private local capture procedure.
- [`blueprint/BLUEPRINT.md`](blueprint/BLUEPRINT.md) — architecture reference without runtime data.

## Evidence policy

- Real captures, logs, manifests, paths, and probe output stay under the Git-ignored `.local-artifacts/` directory and must never be committed, uploaded, linked from public documentation, or copied into issues and pull requests.
- Public screenshots must be generated from synthetic fixtures. Fixtures must use invented account labels, project names, task titles, paths, timestamps, event IDs, quota values, token totals, thread counts, and cost estimates.
- Replacing a real value with masking is not sufficient when the screenshot or report still describes an identifiable local workload. Regenerate the whole artifact from synthetic input.
- Until a synthetic capture is produced and inspected, documentation must state that public visual evidence is unavailable. Historical captures cannot be reused as current Next verification.

No public Windows runtime screenshot is included in this repository at this revision.
