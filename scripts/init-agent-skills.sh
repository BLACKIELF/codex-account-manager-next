#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOURCE_DIR="$PROJECT_ROOT/.agents/skills"
LINK_VALUE="../.agents/skills"
TARGETS=(
  ".codex/skills"
  ".cursor/skills"
  ".claude/skills"
)

mode="dry-run"

usage() {
  cat <<'EOF'
Usage: scripts/init-agent-skills.sh [--apply]

Without --apply, report the symlinks that would be created. With --apply,
create project-local Codex compatibility, Cursor, and Claude Code skill links
to .agents/skills. Existing real paths and links to another source are reported
as conflicts and are never overwritten.
EOF
}

case "${1:-}" in
  "") ;;
  --apply) mode="apply" ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: canonical skill directory is missing: $SOURCE_DIR" >&2
  exit 1
fi

if ! compgen -G "$SOURCE_DIR/*/SKILL.md" >/dev/null; then
  echo "ERROR: no project skill was found under $SOURCE_DIR" >&2
  exit 1
fi

source_link="$(find "$SOURCE_DIR" -type l -print -quit)"
if [[ -n "$source_link" ]]; then
  echo "ERROR: canonical skill content must not contain symlinks: $source_link" >&2
  exit 1
fi

for skill_dir in "$SOURCE_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "ERROR: invalid skill directory name: $skill_name" >&2
    exit 1
  fi
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    echo "ERROR: skill is missing SKILL.md: $skill_dir" >&2
    exit 1
  fi
  frontmatter_name="$(awk '/^name:/{sub(/^name:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit}' "$skill_dir/SKILL.md")"
  frontmatter_description="$(awk '/^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_dir/SKILL.md")"
  frontmatter_keys="$(awk 'NR == 1 && $0 == "---" { inside = 1; next } inside && $0 == "---" { exit } inside && /^[A-Za-z0-9_-]+:/ { sub(/:.*/, ""); print }' "$skill_dir/SKILL.md")"
  if [[ "$frontmatter_name" != "$skill_name" ]]; then
    echo "ERROR: skill name does not match its directory: $skill_dir" >&2
    exit 1
  fi
  if [[ -z "$frontmatter_description" ]]; then
    echo "ERROR: skill description is missing: $skill_dir/SKILL.md" >&2
    exit 1
  fi
  if [[ "$frontmatter_keys" != $'name\ndescription' ]]; then
    echo "ERROR: SKILL.md frontmatter must contain only name and description: $skill_dir/SKILL.md" >&2
    exit 1
  fi
done

resolve_link() {
  local link_path="$1"
  local raw_target candidate
  raw_target="$(readlink "$link_path")"
  if [[ "$raw_target" = /* ]]; then
    candidate="$raw_target"
  else
    candidate="$(dirname "$link_path")/$raw_target"
  fi
  if [[ -d "$candidate" ]]; then
    (cd "$candidate" && pwd -P)
  fi
}

conflicts=0
for relative_target in "${TARGETS[@]}"; do
  target="$PROJECT_ROOT/$relative_target"
  if [[ -L "$target" ]]; then
    resolved="$(resolve_link "$target")"
    if [[ "$resolved" == "$SOURCE_DIR" ]]; then
      echo "OK: $relative_target -> $LINK_VALUE"
    else
      echo "CONFLICT: $relative_target is a symlink to $(readlink "$target")" >&2
      conflicts=$((conflicts + 1))
    fi
  elif [[ -e "$target" ]]; then
    echo "CONFLICT: $relative_target already exists and is not a symlink" >&2
    conflicts=$((conflicts + 1))
  else
    echo "PLAN: create $relative_target -> $LINK_VALUE"
  fi
done

if (( conflicts > 0 )); then
  echo "ERROR: found $conflicts conflict(s); no paths were changed" >&2
  exit 1
fi

if [[ "$mode" == "dry-run" ]]; then
  echo "Dry-run complete. Re-run with --apply to create missing links."
  exit 0
fi

for relative_target in "${TARGETS[@]}"; do
  target="$PROJECT_ROOT/$relative_target"
  [[ -L "$target" ]] && continue
  mkdir -p "$(dirname "$target")"
  ln -s "$LINK_VALUE" "$target"
  echo "CREATED: $relative_target -> $LINK_VALUE"
done

echo "Project skills initialized from .agents/skills."
