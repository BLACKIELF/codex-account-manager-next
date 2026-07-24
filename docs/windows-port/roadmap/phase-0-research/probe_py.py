#!/usr/bin/env python3
"""
Python equivalent of probe.ps1 for Windows data-path discovery.
Zero dependencies beyond Python stdlib.
"""
from __future__ import annotations

import datetime
import glob
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "findings.yaml"


def escape_yaml(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    s = str(value)
    if re.search(r"[\:\[\]\{\}\,\&\*\#\?\|\-\<\>\=\!\%\\@\`]", s) or s.startswith(" ") or s.endswith(" ") or s == "":
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s


def first_existing(paths: list[Path]) -> Path | None:
    for p in paths:
        if p.exists():
            return p
    return None


def any_file(pattern: Path) -> bool:
    if "*" not in str(pattern):
        return pattern.exists()
    return bool(glob.glob(str(pattern), recursive=True))


def first_file(pattern: Path) -> Path | None:
    if "*" not in str(pattern):
        return pattern if pattern.exists() else None
    matches = glob.glob(str(pattern), recursive=True)
    for p in matches:
        path = Path(p)
        if path.is_file():
            return path
    return None


def has_bom(path: Path) -> bool | None:
    if not path.exists():
        return None
    with path.open("rb") as f:
        return f.read(3) == b"\xef\xbb\xbf"


def jsonl_fields(path: Path, sample_lines: int = 5) -> list[str]:
    if not path.exists():
        return []
    fields: set[str] = set()
    count = 0
    with path.open("r", encoding="utf-8-sig") as f:
        for line in f:
            if count >= sample_lines:
                break
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                if isinstance(obj, dict):
                    for k in obj.keys():
                        fields.add(k)
                    msg = obj.get("message")
                    if isinstance(msg, dict):
                        for k in msg.keys():
                            fields.add(f"message.{k}")
            except Exception:
                pass
            count += 1
    return sorted(fields)


def sqlite_schema(db_path: Path) -> dict[str, Any]:
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        cur = conn.cursor()
        cur.execute("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL")
        schema = "\n".join(row[0] for row in cur.fetchall())
        conn.close()
    except Exception as e:
        return {"has_threads_table": False, "has_rollout_path": False, "has_thread_spawn_edges": False, "notes": f"sqlite error: {e}"}

    return {
        "has_threads_table": "CREATE TABLE threads" in schema,
        "has_rollout_path": "rollout_path" in schema,
        "has_thread_spawn_edges": "CREATE TABLE thread_spawn_edges" in schema,
        "notes": "schema matches macOS reference" if "CREATE TABLE threads" in schema and "rollout_path" in schema and "CREATE TABLE thread_spawn_edges" in schema else "schema differs from macOS reference",
    }


def app_server_available() -> dict[str, Any]:
    codex = shutil.which("codex")
    if not codex:
        return {"available": False, "notes": "codex CLI not found in PATH"}
    try:
        result = subprocess.run([codex, "app-server", "--help"], capture_output=True, text=True, timeout=10)
        text = (result.stdout + "; " + result.stderr).strip()
        return {"available": result.returncode == 0, "notes": text[:200]}
    except Exception as e:
        return {"available": False, "notes": f"error: {e}"}


# =============== Codex probe ===============
codex_roots = [
    Path(os.environ["USERPROFILE"]) / ".codex",
    Path(os.environ["LOCALAPPDATA"]) / "Codex",
    Path(os.environ["APPDATA"]) / "Codex",
]
codex_data_root = first_existing(codex_roots)

state5_path: Path | None = None
if codex_data_root:
    state5_path = first_existing([
        codex_data_root / "state_5.sqlite",
        codex_data_root / "sqlite" / "state_5.sqlite",
    ])

codex_jsonl_pattern: Path | None = None
if codex_data_root:
    for pat in [
        codex_data_root / "sessions" / "**" / "rollout-*.jsonl",
        codex_data_root / "sessions" / "**" / "*.jsonl",
        codex_data_root / "archived_sessions" / "*.jsonl",
    ]:
        if any_file(pat):
            codex_jsonl_pattern = pat
            break

codex_jsonl_sample = first_file(codex_jsonl_pattern) if codex_jsonl_pattern else None
codex_jsonl_fields = jsonl_fields(codex_jsonl_sample) if codex_jsonl_sample else []
codex_jsonl_bom = has_bom(codex_jsonl_sample) if codex_jsonl_sample else None

automation_pattern = codex_data_root / "automations" / "**" / "automation.toml" if codex_data_root else None
automation_exists = any_file(automation_pattern) if automation_pattern else False

# =============== Claude Code probe ===============
claude_roots = [
    Path(os.environ["USERPROFILE"]) / ".claude",
    Path(os.environ["APPDATA"]) / "Claude",
    Path(os.environ["LOCALAPPDATA"]) / "Claude",
]
claude_data_root = first_existing(claude_roots)

claude_transcript_pattern: Path | None = None
if claude_data_root:
    pat = claude_data_root / "projects" / "**" / "*.jsonl"
    if any_file(pat):
        claude_transcript_pattern = pat

claude_transcript_sample = first_file(claude_transcript_pattern) if claude_transcript_pattern else None
claude_transcript_fields = jsonl_fields(claude_transcript_sample) if claude_transcript_sample else []
claude_transcript_bom = has_bom(claude_transcript_sample) if claude_transcript_sample else None

claude_tasks_pattern = claude_data_root / "tasks" / "**" / "*.json" if claude_data_root else None
claude_tasks_exist = any_file(claude_tasks_pattern) if claude_tasks_pattern else False

claude_global_state_path = Path(os.environ["USERPROFILE"]) / ".claude.json"
claude_global_state_exists = claude_global_state_path.exists()

statusline_path = Path(os.environ["LOCALAPPDATA"]) / "codexU" / "claude-code" / "statusline-snapshot.json"
statusline_exists = statusline_path.exists()

# =============== Schema / app-server ===============
schema_result = sqlite_schema(state5_path) if state5_path else None
app_server_result = app_server_available()

# =============== Build findings ===============
findings: dict[str, Any] = {
    "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
    "codex": {
        "supported": codex_data_root is not None,
        "data_root": str(codex_data_root) if codex_data_root else None,
        "state_5_sqlite": {
            "exists": state5_path is not None,
            "path": str(state5_path) if state5_path else None,
            "schema_matches_macos": bool(schema_result and schema_result["has_threads_table"] and schema_result["has_rollout_path"] and schema_result["has_thread_spawn_edges"]),
            "schema_notes": schema_result["notes"] if schema_result else "database not found",
        },
        "sessions_jsonl": {
            "exists": codex_jsonl_sample is not None,
            "pattern": str(codex_jsonl_pattern) if codex_jsonl_pattern else None,
            "sample_path": str(codex_jsonl_sample) if codex_jsonl_sample else None,
            "event_types": [f for f in codex_jsonl_fields if f in ("token_count", "task_started", "task_complete")],
            "all_fields": codex_jsonl_fields,
            "has_bom": codex_jsonl_bom,
        },
        "automations": {
            "exists": automation_exists,
            "pattern": str(automation_pattern) if automation_pattern else None,
        },
        "app_server": app_server_result,
    },
    "claude_code": {
        "supported": claude_data_root is not None,
        "data_root": str(claude_data_root) if claude_data_root else None,
        "transcripts": {
            "exists": claude_transcript_sample is not None,
            "pattern": str(claude_transcript_pattern) if claude_transcript_pattern else None,
            "sample_path": str(claude_transcript_sample) if claude_transcript_sample else None,
            "fields": claude_transcript_fields,
            "has_bom": claude_transcript_bom,
        },
        "tasks": {
            "exists": claude_tasks_exist,
            "pattern": str(claude_tasks_pattern) if claude_tasks_pattern else None,
        },
        "global_state": {
            "exists": claude_global_state_exists,
            "path": str(claude_global_state_path),
        },
        "statusline_snapshot": {
            "exists": statusline_exists,
            "path": str(statusline_path),
            "notes": "Run Claude Code with codexU integration to generate" if not statusline_exists else "found",
        },
    },
}

risk: list[str] = []
if not findings["codex"]["supported"]:
    risk.append("Codex data root not found. May need to install/run Codex CLI first.")
if not findings["codex"]["state_5_sqlite"]["exists"]:
    risk.append("state_5.sqlite not found. Codex provider cannot read thread metadata.")
if findings["codex"]["state_5_sqlite"]["exists"] and not findings["codex"]["state_5_sqlite"]["schema_matches_macos"]:
    risk.append("state_5.sqlite schema differs from macOS. Parser may need adaptation.")
if not findings["codex"]["sessions_jsonl"]["exists"]:
    risk.append("Codex JSONL sessions not found. Token breakdown may be unavailable.")
if not findings["codex"]["app_server"]["available"]:
    risk.append("codex app-server unavailable. Quota display may rely on local data only.")
if findings["codex"]["sessions_jsonl"]["has_bom"] is True:
    risk.append("Codex JSONL has UTF-8 BOM. Parser must handle BOM.")
if not findings["claude_code"]["supported"]:
    risk.append("Claude Code data root not found. Claude Code provider can be deferred.")

findings["risk_assessment"] = risk

if not findings["codex"]["supported"] and not findings["claude_code"]["supported"]:
    recommendation = "STOP: No Codex or Claude Code data found. Install and use the tools first, then re-run probe."
elif findings["codex"]["supported"] and findings["codex"]["state_5_sqlite"]["schema_matches_macos"]:
    recommendation = "GO: Enter phase-1-core-prototype. Consider deferring Claude Code provider if its data is missing."
elif findings["codex"]["supported"]:
    recommendation = "CAUTION: Enter phase-1-core-prototype with reduced scope. Adapt parsers for schema differences."
else:
    recommendation = "DEFER: Wait for Codex Windows support or focus on Claude Code only."

findings["recommendation"] = recommendation


def write_yaml(value: Any, indent: int = 0) -> str:
    prefix = " " * indent
    lines: list[str] = []
    if isinstance(value, dict):
        for k, v in value.items():
            if isinstance(v, dict):
                lines.append(f"{prefix}{k}:")
                lines.append(write_yaml(v, indent + 2))
            elif isinstance(v, list):
                lines.append(f"{prefix}{k}:")
                for item in v:
                    if isinstance(item, dict):
                        lines.append(f"{prefix}  -")
                        for kk, vv in item.items():
                            lines.append(f"{prefix}    {kk}: {escape_yaml(vv)}")
                    else:
                        lines.append(f"{prefix}  - {escape_yaml(item)}")
            else:
                lines.append(f"{prefix}{k}: {escape_yaml(v)}")
    return "\n".join(lines)


out = [
    "# codexU Windows Data Path Findings",
    f"# Generated: {findings['generated_at']}",
    "",
    write_yaml({"codex": findings["codex"]}, 0),
    "",
    write_yaml({"claude_code": findings["claude_code"]}, 0),
    "",
    "risk_assessment:",
]
for r in risk:
    out.append(f"  - {escape_yaml(r)}")
out.append("")
out.append(f"recommendation: {escape_yaml(recommendation)}")

OUTPUT.write_text("\n".join(out), encoding="utf-8")

print("\n========== codexU Windows Data Path Probe ==========")
print(f"Codex data root:     {findings['codex']['data_root']}")
print(f"state_5.sqlite:      {findings['codex']['state_5_sqlite']['path']}")
print(f"Codex JSONL found:   {findings['codex']['sessions_jsonl']['exists']}")
print(f"Claude data root:    {findings['claude_code']['data_root']}")
print(f"Claude JSONL found:  {findings['claude_code']['transcripts']['exists']}")
print(f"app-server available:{findings['codex']['app_server']['available']}")
print(f"Recommendation:      {recommendation}")
print(f"\nFull findings written to: {OUTPUT}")
