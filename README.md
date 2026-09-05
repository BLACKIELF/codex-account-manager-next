# Next historical application backups

This branch retains the user's previous local macOS application bundles before an in-place upgrade. These are historical recovery copies, not a new release or a recommendation to run parallel app instances.

Each ZIP contains only `CodexAccountManagerNext.app` and macOS archive metadata. Account homes, credentials, application-support data and user preferences are not included. The bundles use ad-hoc signing; Apple notarization was not performed.

| Previous app | ZIP | SHA-256 |
| --- | --- | --- |
| 0904v1 / build 11 | `CodexAccountManagerNext-0904v1-build11.zip` | `39a4266c0e6dcbf1501d31437e1a0c2a63429785f03140cec167e378e3894f91` |
| 0904v2 / build 12 | `CodexAccountManagerNext-0904v2-build12.zip` | `4986b681260409cef3ceae47a0c55268d8d0ebf415e3207573bc4b0a1bd815e2` |

Both ZIP integrity checks passed before upload. This archive is separate from `main` so old binaries do not enlarge normal source checkouts. Keep only the most recent previous-app ZIP in the local release-archives folder after verifying these remote backups.
