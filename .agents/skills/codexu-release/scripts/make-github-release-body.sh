#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <release-notes.md> <output.md>" >&2
  exit 64
fi

source_notes=$1
output_file=$2

if [[ ! -f "$source_notes" ]]; then
  echo "release notes not found: $source_notes" >&2
  exit 66
fi

output_dir=$(dirname "$output_file")
mkdir -p "$output_dir"
temporary_file=$(mktemp "$output_dir/.github-release-body.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

awk '
  BEGIN {
    found_updates = 0
    in_updates = 0
    update_count = 0
    update_content = 0
    heading = ""
  }

  {
    line = $0

    if (!found_updates && (line == "## Highlights" || line == "## 主要更新")) {
      found_updates = 1
      in_updates = 1
      heading = line
      next
    }

    if (!found_updates) { next }

    if (in_updates && line ~ /^##[[:space:]]/) {
      in_updates = 0
    }

    if (in_updates) {
      updates[++update_count] = line
      if (line !~ /^[[:space:]]*$/) {
        update_content = 1
      }
    }
  }

  END {
    if (!found_updates || !update_content) {
      print "release notes must contain a non-empty ## Highlights or ## 主要更新 section" > "/dev/stderr"
      exit 1
    }

    while (update_count > 0 && updates[update_count] ~ /^[[:space:]]*$/) {
      update_count--
    }

    print heading
    for (line_number = 1; line_number <= update_count; line_number++) {
      print updates[line_number]
    }
  }
' "$source_notes" > "$temporary_file"

mv "$temporary_file" "$output_file"
trap - EXIT
