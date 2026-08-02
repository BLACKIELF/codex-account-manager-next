#!/usr/bin/env python3
"""Deterministically render the codexU Windows Blueprint from schema.yaml."""

from __future__ import annotations

import argparse
import html
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    import yaml
except ImportError as exc:  # pragma: no cover - runtime guidance
    raise SystemExit("Missing PyYAML. Run with: uv run --with pyyaml python render.py") from exc


FONT = "'Segoe UI','Microsoft YaHei UI','Noto Sans CJK SC',sans-serif"


@dataclass(frozen=True)
class Box:
    x: float
    y: float
    w: float
    h: float

    @property
    def left(self) -> float:
        return self.x

    @property
    def right(self) -> float:
        return self.x + self.w

    @property
    def top(self) -> float:
        return self.y

    @property
    def bottom(self) -> float:
        return self.y + self.h

    @property
    def cx(self) -> float:
        return self.x + self.w / 2

    @property
    def cy(self) -> float:
        return self.y + self.h / 2


def esc(value: Any) -> str:
    return html.escape(str(value), quote=True)


def load_schema(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def box_for(node: dict[str, Any]) -> Box:
    layout = node.get("layout") or {}
    return Box(
        float(layout["x"]),
        float(layout["y"]),
        float(layout["w"]),
        float(layout["h"]),
    )


def weighted_len(text: str) -> float:
    return sum(1.0 if ord(ch) < 128 else 1.75 for ch in text)


def wrap_text(value: Any, limit: float, max_lines: int) -> list[str]:
    text = str(value or "").strip()
    if not text:
        return []
    words = text.split(" ")
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if weighted_len(candidate) <= limit:
            current = candidate
            continue
        if current:
            lines.append(current)
            current = word
        else:
            chunk = ""
            for char in word:
                if chunk and weighted_len(chunk + char) > limit:
                    lines.append(chunk)
                    chunk = char
                else:
                    chunk += char
            current = chunk
        if len(lines) >= max_lines:
            break
    if current and len(lines) < max_lines:
        lines.append(current)
    if len(lines) == max_lines and weighted_len(" ".join(words)) > sum(weighted_len(x) for x in lines):
        lines[-1] = lines[-1].rstrip("…") + "…"
    return lines[:max_lines]


def text_element(
    value: str,
    x: float,
    y: float,
    size: float,
    weight: int,
    color: str,
    anchor: str = "start",
    opacity: float = 1.0,
    letter_spacing: float = 0.0,
) -> str:
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="{size:.1f}" '
        f'font-weight="{weight}" fill="{color}" text-anchor="{anchor}" opacity="{opacity:.2f}" '
        f'letter-spacing="{letter_spacing:.1f}">{esc(value)}</text>'
    )


def lines_svg(
    lines: Iterable[str],
    x: float,
    y: float,
    size: float,
    weight: int,
    color: str,
    line_height: float,
    anchor: str = "start",
) -> str:
    return "\n".join(
        text_element(line, x, y + index * line_height, size, weight, color, anchor)
        for index, line in enumerate(lines)
    )


def group_frame(group: dict[str, Any], boxes: dict[str, Box]) -> str:
    members = [boxes[str(node_id)] for node_id in group.get("nodes", [])]
    x = min(box.left for box in members) - 38
    y = min(box.top for box in members) - 74
    right = max(box.right for box in members) + 38
    bottom = max(box.bottom for box in members) + 82
    label = str(group.get("label", ""))
    return "\n".join(
        [
            f'<g id="group-{esc(group["id"])}">',
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{right - x:.1f}" height="{bottom - y:.1f}" rx="30" '
            f'fill="{esc(group.get("fill", "#0c1528"))}" fill-opacity="0.82" '
            f'stroke="{esc(group.get("stroke", "#5f7192"))}" stroke-width="2"/>',
            f'<rect x="{x + 22:.1f}" y="{y + 18:.1f}" width="10" height="26" rx="5" fill="#81bcff"/>',
            text_element(label, x + 46, y + 39, 20, 700, "#eaf2ff"),
            text_element("CURRENT WINDOWS RUNTIME", right - 22, y + 37, 11, 700, "#8191ae", "end", 1.0, 1.3),
            "</g>",
        ]
    )


def node_svg(node: dict[str, Any], box: Box, category: dict[str, Any]) -> str:
    node_id = str(node["id"])
    fill = str(category.get("fill", "#222b3c"))
    stroke = str(category.get("stroke", "#6f86a8"))
    accent = str(category.get("accent", stroke))
    dashed = ' stroke-dasharray="8 6"' if node.get("style") == "dashed" else ""
    runtime = str(node.get("layer")) == "runtime"
    pad = 20 if runtime else 18
    title_limit = 30
    title_lines = wrap_text(node.get("label"), title_limit, 2)
    signature_lines = wrap_text(node.get("signature"), 35 if runtime else 39, 2)
    note_lines = wrap_text(node.get("note"), 34 if runtime else 39, 1)
    title_size = 16 if runtime else 15
    if runtime:
        title_y = box.y + 36
        signature_y = title_y + len(title_lines) * 23 + 12
        note_y = signature_y + len(signature_lines) * 18 + 11
        title_height = 23
        signature_height = 18
    else:
        title_y = box.y + 31
        title_height = 21
        signature_height = 16
        signature_y = max(box.y + 72, title_y + len(title_lines) * title_height + 8)
        note_y = max(box.y + 111, signature_y + len(signature_lines) * signature_height + 8)
    parts = [
        f'<g id="node-{esc(node_id)}">',
        f'<rect x="{box.x:.1f}" y="{box.y:.1f}" width="{box.w:.1f}" height="{box.h:.1f}" rx="20" '
        f'fill="{esc(fill)}" stroke="{esc(stroke)}" stroke-width="1.8"{dashed} filter="url(#card-shadow)"/>',
        f'<rect x="{box.x + 1:.1f}" y="{box.y + 1:.1f}" width="5" height="{box.h - 2:.1f}" rx="3" fill="{esc(accent)}"/>',
        lines_svg(title_lines, box.x + pad, title_y, title_size, 720, "#f5f8ff", title_height),
        lines_svg(signature_lines, box.x + pad, signature_y, 11.5, 600, accent, signature_height),
        lines_svg(note_lines, box.x + pad, note_y, 11.5, 430, "#aebbd0", 18),
    ]
    insets = [str(item) for item in node.get("insets") or []]
    if insets:
        inset_y = box.bottom - 39
        usable = box.w - pad * 2
        gap = 8
        inset_w = (usable - gap * (len(insets) - 1)) / len(insets)
        for index, inset in enumerate(insets):
            inset_x = box.x + pad + index * (inset_w + gap)
            parts.append(
                f'<rect x="{inset_x:.1f}" y="{inset_y:.1f}" width="{inset_w:.1f}" height="24" rx="8" '
                'fill="#07101f" fill-opacity="0.56" stroke="#ffffff" stroke-opacity="0.08"/>'
            )
            parts.append(text_element(inset, inset_x + inset_w / 2, inset_y + 16, 9.6, 600, "#c5d0e1", "middle"))
    parts.append("</g>")
    return "\n".join(parts)


def anchor(box: Box, side: str, ratio: float = 0.5) -> tuple[float, float]:
    if side == "top":
        return box.x + box.w * ratio, box.top
    if side == "bottom":
        return box.x + box.w * ratio, box.bottom
    if side == "left":
        return box.left, box.y + box.h * ratio
    return box.right, box.y + box.h * ratio


def route_edge(edge: dict[str, Any], source: Box, target: Box) -> list[tuple[float, float]]:
    kind = str(edge.get("kind", "data_flow"))
    if kind in {"data_flow", "contract"} and abs(source.cy - target.cy) < 10:
        return [anchor(source, "right"), anchor(target, "left")]

    if edge.get("route"):
        start_side = str(edge.get("from_side") or ("top" if target.cy < source.cy else "bottom"))
        end_side = str(edge.get("to_side") or ("bottom" if target.cy < source.cy else "top"))
        start_ratio = float(edge.get("from_ratio", 0.5))
        end_ratio = float(edge.get("to_ratio", 0.5))
        return [anchor(source, start_side, start_ratio), *[(float(x), float(y)) for x, y in edge["route"]], anchor(target, end_side, end_ratio)]

    if kind == "captures":
        start = anchor(source, "top", 0.74)
        end = anchor(target, "bottom", 0.74)
        mid_y = (start[1] + end[1]) / 2
        return [start, (start[0], mid_y), (end[0], mid_y), end]
    if kind == "produces":
        start = anchor(source, "left", 0.70)
        end = anchor(target, "right", 0.50)
        bend_x = (start[0] + end[0]) / 2
        return [start, (bend_x, start[1]), (bend_x, end[1]), end]
    if kind == "builds" and target.x > source.x + source.w:
        start = anchor(source, "right", 0.45)
        end = anchor(target, "left", 0.75)
        bend_x = (start[0] + end[0]) / 2
        return [start, (bend_x, start[1]), (bend_x, end[1]), end]

    upward = target.cy < source.cy
    if upward:
        source_ratio = 0.50
        target_ratio = 0.50
        if kind == "captures":
            source_ratio = target_ratio = 0.75
        elif kind == "builds" and str(edge.get("to")) == "windows_desktop_ui":
            target_ratio = 0.25
        elif kind == "consumes":
            target_ratio = 0.36 if str(edge.get("to")) == "safe_readers" else 0.64
        source_ratio = float(edge.get("from_ratio", source_ratio))
        target_ratio = float(edge.get("to_ratio", target_ratio))
        start = anchor(source, str(edge.get("from_side") or "top"), source_ratio)
        end = anchor(target, str(edge.get("to_side") or "bottom"), target_ratio)
    else:
        start = anchor(source, str(edge.get("from_side") or "bottom"), float(edge.get("from_ratio", 0.5)))
        end = anchor(target, str(edge.get("to_side") or "top"), float(edge.get("to_ratio", 0.5)))

    offset = (sum(ord(ch) for ch in str(edge.get("label", ""))) % 5 - 2) * 14
    mid_y = (start[1] + end[1]) / 2 + offset
    return [start, (start[0], mid_y), (end[0], mid_y), end]


def longest_segment_midpoint(points: list[tuple[float, float]]) -> tuple[float, float]:
    best = max(
        zip(points, points[1:]),
        key=lambda pair: abs(pair[0][0] - pair[1][0]) + abs(pair[0][1] - pair[1][1]),
    )
    (x1, y1), (x2, y2) = best
    return ((x1 + x2) / 2, (y1 + y2) / 2)


def edge_svg(edge: dict[str, Any], boxes: dict[str, Box]) -> str:
    source_id = str(edge["from"])
    target_id = str(edge["to"])
    kind = str(edge.get("kind", "data_flow"))
    points = route_edge(edge, boxes[source_id], boxes[target_id])
    point_text = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    styles = {
        "data_flow": ("#63b3ff", "", 2.7),
        "read_only": ("#82aef5", "7 5", 2.2),
        "contract": ("#a99aff", "", 2.7),
        "verifies": ("#8395b1", "7 6", 1.8),
        "captures": ("#f39bdc", "", 2.5),
        "produces": ("#e5b65b", "", 2.2),
        "consumes": ("#96a6bb", "4 5", 1.8),
        "builds": ("#a8b1c0", "3 5", 1.8),
    }
    color, dash, width = styles.get(kind, ("#8fa0b8", "", 2.0))
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    crossing = esc(edge.get("crossing_style", ""))
    label = str(edge.get("label", ""))
    label_x, label_y = longest_segment_midpoint(points)
    label_w = min(max(weighted_len(label) * 6.0 + 20, 86), 230)
    label_y -= 3
    return "\n".join(
        [
            f'<g class="edge edge-{esc(source_id)}-{esc(target_id)}" data-crossing-style="{crossing}">',
            f'<polyline points="{point_text}" fill="none" stroke="{color}" stroke-width="{width:.1f}" '
            f'stroke-linecap="round" stroke-linejoin="round" marker-end="url(#arrow-{kind})"{dash_attr}/>',
            '<g class="edge-label">',
            f'<rect x="{label_x - label_w / 2:.1f}" y="{label_y - 14:.1f}" width="{label_w:.1f}" height="21" rx="7" '
            'fill="#081120" fill-opacity="0.94" stroke="#263754" stroke-width="0.8"/>',
            text_element(label, label_x, label_y + 1, 9.8, 650, color, "middle"),
            "</g>",
            "</g>",
        ]
    )


def bridge_overlay_svg(edge: dict[str, Any]) -> str:
    points = edge.get("bridge_points") or []
    if not points:
        return ""
    color = "#82aef5" if edge.get("kind") == "read_only" else "#8395b1"
    parts = [f'<g class="edge-bridges" data-edge="{esc(edge["from"])}-{esc(edge["to"])}">']
    for x, y in points:
        x = float(x)
        y = float(y)
        radius = 9.0
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius:.1f}" fill="#0b1424"/>')
        parts.append(
            f'<path d="M {x - radius:.1f},{y:.1f} Q {x:.1f},{y - radius:.1f} {x + radius:.1f},{y:.1f}" '
            f'fill="none" stroke="{color}" stroke-width="2.2" stroke-linecap="round"/>'
        )
    parts.append("</g>")
    return "\n".join(parts)


def callout_svg(callout: dict[str, Any]) -> str:
    layout = callout.get("layout") or {}
    x, y = float(layout["x"]), float(layout["y"])
    w, h = float(layout["w"]), float(layout["h"])
    return "\n".join(
        [
            f'<g id="callout-{esc(callout["id"])}">',
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{h / 2:.1f}" '
            f'fill="{esc(callout.get("fill", "#17233a"))}" stroke="{esc(callout.get("stroke", "#536786"))}"/>',
            text_element(str(callout.get("label", "")), x + w / 2, y + h / 2 + 4, 10, 700, "#cad5e7", "middle", 1.0, 0.7),
            "</g>",
        ]
    )


def render_svg(schema: dict[str, Any]) -> str:
    meta = schema.get("meta") or {}
    canvas = meta.get("canvas") or {}
    width = int(canvas.get("width", 1800))
    height = int(canvas.get("height", 1400))
    nodes = schema.get("nodes") or []
    boxes = {str(node["id"]): box_for(node) for node in nodes}
    categories = schema.get("categories") or {}
    marker_kinds = ["data_flow", "read_only", "contract", "verifies", "captures", "produces", "consumes", "builds"]
    marker_colors = {
        "data_flow": "#63b3ff", "read_only": "#82aef5", "contract": "#a99aff",
        "verifies": "#8395b1", "captures": "#f39bdc", "produces": "#e5b65b",
        "consumes": "#96a6bb", "builds": "#a8b1c0",
    }
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        "<defs>",
        '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#07101e"/><stop offset="0.55" stop-color="#0b1424"/><stop offset="1" stop-color="#10172a"/></linearGradient>',
        '<pattern id="grid" width="32" height="32" patternUnits="userSpaceOnUse"><path d="M 32 0 L 0 0 0 32" fill="none" stroke="#9fb3d1" stroke-opacity="0.035" stroke-width="1"/></pattern>',
        '<filter id="card-shadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000814" flood-opacity="0.42"/></filter>',
    ]
    for kind in marker_kinds:
        parts.append(
            f'<marker id="arrow-{kind}" markerWidth="10" markerHeight="10" refX="8.5" refY="5" orient="auto" markerUnits="strokeWidth">'
            f'<path d="M1,1 L9,5 L1,9 Z" fill="{marker_colors[kind]}"/></marker>'
        )
    parts.extend(
        [
            "</defs>",
            '<rect width="100%" height="100%" fill="url(#bg)"/>',
            '<rect width="100%" height="100%" fill="url(#grid)"/>',
            text_element(str(meta.get("title", "Architecture Blueprint")), 72, 72, 31, 760, "#f3f7ff"),
            text_element(str(meta.get("subtitle", "")), 72, 103, 15, 450, "#91a4c2"),
            text_element(f'SCHEMA {meta.get("version", "")} · {meta.get("updated", "")}', width - 66, 68, 11, 700, "#71829f", "end", 1.0, 1.2),
            text_element("solid = runtime / operational flow", width - 66, 94, 10.5, 550, "#8191aa", "end"),
            text_element("dashed = verifies / read-only context", width - 66, 112, 10.5, 550, "#8191aa", "end"),
            '<g id="groups">',
        ]
    )
    parts.extend(group_frame(group, boxes) for group in schema.get("groups") or [])
    parts.extend(["</g>", '<g id="edges">'])
    edges = schema.get("edges") or []
    parts.extend(edge_svg(edge, boxes) for edge in edges)
    parts.extend(bridge_overlay_svg(edge) for edge in edges if edge.get("bridge_points"))
    parts.extend(["</g>", '<g id="nodes">'])
    parts.extend(node_svg(node, boxes[str(node["id"])], categories[str(node["category"])]) for node in nodes)
    parts.extend(["</g>", '<g id="callouts">'])
    parts.extend(callout_svg(callout) for callout in schema.get("callouts") or [])
    parts.extend(["</g>", "</svg>"])
    return "\n".join(parts)


def write_html(svg: str, path: Path) -> None:
    document = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>codexU Windows Desktop Blueprint</title>
  <style>
    * {{ box-sizing: border-box; }}
    html, body {{ margin: 0; width: 100%; min-height: 100%; background: #050b14; }}
    .canvas {{ width: min(1800px, 100vw); margin: 0 auto; overflow: auto; }}
    svg {{ display: block; width: 100%; height: auto; }}
  </style>
</head>
<body>
  <div class="canvas">{svg}</div>
</body>
</html>
"""
    path.write_text(document, encoding="utf-8")


def render(schema_path: Path, out_dir: Path) -> tuple[Path, Path]:
    schema = load_schema(schema_path)
    svg = render_svg(schema)
    out_dir.mkdir(parents=True, exist_ok=True)
    svg_path = out_dir / "diagram.svg"
    html_path = out_dir / "diagram.html"
    svg_path.write_text(svg, encoding="utf-8")
    write_html(svg, html_path)
    return svg_path, html_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", type=Path, default=Path(__file__).with_name("schema.yaml"))
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).parent)
    args = parser.parse_args()
    svg_path, html_path = render(args.schema, args.out_dir)
    print(f"wrote {svg_path}")
    print(f"wrote {html_path}")


if __name__ == "__main__":
    main()
