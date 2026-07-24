#!/usr/bin/env python3
"""Deterministic architecture renderer for blueprint schemas.

Reads docs/architecture/schema.yaml and writes diagram.svg, diagram.html, and
optionally diagram.png when cairosvg is available.

Intended as a starter renderer. Copy this file into a project as
docs/architecture/render.py, then customize layout/style locally.
"""

from __future__ import annotations

import argparse
import html
import math
import pathlib
import textwrap
from dataclasses import dataclass
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - runtime guidance
    raise SystemExit(
        "Missing dependency: pyyaml. Run with: uv run --with pyyaml python render.py"
    ) from exc


CANVAS_W = 1800
MARGIN_X = 92
TOP_Y = 145
ROW_GAP = 188
CARD_W = 300
CARD_H = 116
CARD_R = 18
MAX_PER_ROW = 4


@dataclass
class Box:
    id: str
    x: float
    y: float
    w: float
    h: float

    @property
    def cx(self) -> float:
        return self.x + self.w / 2

    @property
    def top(self) -> float:
        return self.y

    @property
    def bottom(self) -> float:
        return self.y + self.h


def esc(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def load_schema(path: pathlib.Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def wrap_text(text: str, width: int) -> list[str]:
    if not text:
        return []
    chunks: list[str] = []
    for part in str(text).splitlines():
        if len(part) <= width:
            chunks.append(part)
        else:
            chunks.extend(textwrap.wrap(part, width=width, break_long_words=False) or [part])
    return chunks


def layer_key(node: dict[str, Any]) -> str:
    return str(node.get("layer") or "middle")


def compute_layout(nodes: list[dict[str, Any]]) -> dict[str, Box]:
    layer_order = ["top", "middle", "bottom"]
    layers: dict[str, list[dict[str, Any]]] = {name: [] for name in layer_order}
    for node in nodes:
        layers.setdefault(layer_key(node), []).append(node)

    boxes: dict[str, Box] = {}
    current_y = TOP_Y
    for layer in layer_order + [x for x in layers if x not in layer_order]:
        layer_nodes = layers.get(layer, [])
        if not layer_nodes:
            continue
        row_count = math.ceil(len(layer_nodes) / MAX_PER_ROW)
        for row in range(row_count):
            row_nodes = layer_nodes[row * MAX_PER_ROW : (row + 1) * MAX_PER_ROW]
            span = CANVAS_W - 2 * MARGIN_X
            gap = (span - len(row_nodes) * CARD_W) / max(len(row_nodes) + 1, 1)
            for index, node in enumerate(row_nodes):
                explicit = node.get("layout") or {}
                x = explicit.get("x")
                y = explicit.get("y")
                w = explicit.get("w", CARD_W)
                h = explicit.get("h", CARD_H)
                if x is None:
                    x = MARGIN_X + gap + index * (CARD_W + gap)
                if y is None:
                    y = current_y + row * ROW_GAP
                boxes[str(node["id"])] = Box(str(node["id"]), float(x), float(y), float(w), float(h))
        current_y += row_count * ROW_GAP + 44
    return boxes


def svg_text(lines: list[str], x: float, y: float, size: int, weight: str = "400", color: str = "#111827") -> str:
    out = [f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" fill="{color}">']
    for i, line in enumerate(lines):
        dy = 0 if i == 0 else size + 6
        out.append(f'<tspan x="{x:.1f}" dy="{dy}">{esc(line)}</tspan>')
    out.append("</text>")
    return "\n".join(out)


def node_svg(node: dict[str, Any], box: Box, categories: dict[str, Any]) -> str:
    category = categories.get(node.get("category"), {})
    fill = category.get("fill", "#f9fafb")
    stroke = category.get("stroke", "#64748b")
    dash = ' stroke-dasharray="7 6"' if node.get("style") == "dashed" else ""
    shape = node.get("shape", "rect")

    parts: list[str] = [f'<g id="node-{esc(node["id"])}">']
    if shape == "cylinder":
        parts.append(
            f'<path d="M {box.x:.1f} {box.y+16:.1f} '
            f'C {box.x:.1f} {box.y-5:.1f}, {box.x+box.w:.1f} {box.y-5:.1f}, {box.x+box.w:.1f} {box.y+16:.1f} '
            f'L {box.x+box.w:.1f} {box.y+box.h-16:.1f} '
            f'C {box.x+box.w:.1f} {box.y+box.h+5:.1f}, {box.x:.1f} {box.y+box.h+5:.1f}, {box.x:.1f} {box.y+box.h-16:.1f} Z" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="2"{dash}/>'
        )
        parts.append(
            f'<ellipse cx="{box.cx:.1f}" cy="{box.y+16:.1f}" rx="{box.w/2:.1f}" ry="20" '
            f'fill="none" stroke="{stroke}" stroke-width="2"{dash}/>'
        )
    elif shape == "page":
        parts.append(
            f'<path d="M {box.x:.1f} {box.y:.1f} L {box.x+box.w-28:.1f} {box.y:.1f} '
            f'L {box.x+box.w:.1f} {box.y+28:.1f} L {box.x+box.w:.1f} {box.y+box.h:.1f} '
            f'L {box.x:.1f} {box.y+box.h:.1f} Z" fill="{fill}" stroke="{stroke}" stroke-width="2"{dash}/>'
        )
        parts.append(
            f'<path d="M {box.x+box.w-28:.1f} {box.y:.1f} L {box.x+box.w-28:.1f} {box.y+28:.1f} '
            f'L {box.x+box.w:.1f} {box.y+28:.1f}" fill="none" stroke="{stroke}" stroke-width="2"/>'
        )
    else:
        parts.append(
            f'<rect x="{box.x:.1f}" y="{box.y:.1f}" width="{box.w:.1f}" height="{box.h:.1f}" '
            f'rx="{CARD_R}" fill="{fill}" stroke="{stroke}" stroke-width="2"{dash}/>'
        )

    title_lines = wrap_text(str(node.get("label", "")), 20)
    signature_lines = wrap_text(str(node.get("signature", "")), 32)
    note_lines = wrap_text(str(node.get("note", "")), 34)
    text_x = box.x + 22
    text_y = box.y + 32
    parts.append(svg_text(title_lines[:2], text_x, text_y, 19, "700", "#111827"))
    next_y = text_y + 31 + max(0, len(title_lines[:2]) - 1) * 24
    if signature_lines:
        parts.append(svg_text(signature_lines[:2], text_x, next_y, 13, "700", stroke))
        next_y += 22 + max(0, len(signature_lines[:2]) - 1) * 19
    if note_lines:
        parts.append(
            f'<line x1="{text_x:.1f}" y1="{next_y:.1f}" x2="{box.x+box.w-22:.1f}" y2="{next_y:.1f}" '
            f'stroke="#e5e7eb" stroke-width="1"/>'
        )
        parts.append(svg_text(note_lines[:2], text_x, next_y + 22, 12, "400", "#4b5563"))
    parts.append("</g>")
    return "\n".join(parts)


def edge_svg(edge: dict[str, Any], boxes: dict[str, Box], categories: dict[str, Any], nodes_by_id: dict[str, dict[str, Any]]) -> str:
    source = boxes.get(str(edge.get("from")))
    target = boxes.get(str(edge.get("to")))
    if not source or not target:
        return ""

    source_cat = categories.get(nodes_by_id[source.id].get("category"), {})
    color = source_cat.get("stroke", "#64748b")
    if edge.get("kind") == "orchestration":
        color = "#6b7280"
    dash = ' stroke-dasharray="8 7"' if edge.get("kind") == "calibration" or edge.get("style") == "dashed" else ""

    start_x, start_y = source.cx, source.bottom
    end_x, end_y = target.cx, target.top
    if target.top < source.top:
        start_y = source.top
        end_y = target.bottom
    mid_y = (start_y + end_y) / 2
    points = f"{start_x:.1f},{start_y:.1f} {start_x:.1f},{mid_y:.1f} {end_x:.1f},{mid_y:.1f} {end_x:.1f},{end_y:.1f}"
    label = edge.get("label") or ""
    label_svg = ""
    if label:
        lx = (start_x + end_x) / 2
        ly = mid_y - 8
        label_svg = (
            f'<rect x="{lx-72:.1f}" y="{ly-18:.1f}" width="144" height="24" rx="12" fill="white" stroke="#e5e7eb"/>'
            f'{svg_text([str(label)[:28]], lx-64, ly-2, 11, "600", "#475569")}'
        )
    return (
        f'<g class="edge edge-{esc(source.id)}-{esc(target.id)}">'
        f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.5" marker-end="url(#arrow)"{dash}/>'
        f"{label_svg}</g>"
    )


def group_svg(group: dict[str, Any], boxes: dict[str, Box]) -> str:
    node_ids = [str(x) for x in group.get("nodes", [])]
    group_boxes = [boxes[x] for x in node_ids if x in boxes]
    if not group_boxes:
        return ""

    pad_x = 34
    pad_y = 48
    x1 = min(b.x for b in group_boxes) - pad_x
    y1 = min(b.y for b in group_boxes) - pad_y
    x2 = max(b.x + b.w for b in group_boxes) + pad_x
    y2 = max(b.y + b.h for b in group_boxes) + pad_y
    fill = group.get("fill", "#f8fafc")
    stroke = group.get("stroke", "#cbd5e1")
    label = str(group.get("label", group.get("id", "")))
    dash = ' stroke-dasharray="8 8"' if group.get("style") == "dashed" else ""
    return (
        f'<g id="group-{esc(group.get("id", ""))}">'
        f'<rect x="{x1:.1f}" y="{y1:.1f}" width="{x2-x1:.1f}" height="{y2-y1:.1f}" '
        f'rx="26" fill="{fill}" fill-opacity="0.38" stroke="{stroke}" stroke-width="2"{dash}/>'
        f'{svg_text([label], x1 + 22, y1 + 30, 16, "800", stroke)}'
        f"</g>"
    )


def render_svg(schema: dict[str, Any]) -> str:
    meta = schema.get("meta", {})
    categories = schema.get("categories", {})
    nodes = schema.get("nodes", [])
    edges = schema.get("edges", [])
    groups = schema.get("groups", [])
    boxes = compute_layout(nodes)
    nodes_by_id = {str(n["id"]): n for n in nodes}
    max_y = max((b.bottom for b in boxes.values()), default=900) + 100

    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_W}" height="{int(max_y)}" viewBox="0 0 {CANVAS_W} {int(max_y)}">',
        "<defs>",
        '<marker id="arrow" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto" markerUnits="strokeWidth">',
        '<path d="M2,2 L10,6 L2,10 Z" fill="#64748b"/>',
        "</marker>",
        "</defs>",
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        svg_text([str(meta.get("title", "Architecture Diagram"))], CANVAS_W / 2 - 280, 62, 34, "800", "#0f172a"),
    ]
    subtitle = meta.get("subtitle")
    if subtitle:
        parts.append(svg_text([str(subtitle)], CANVAS_W / 2 - 330, 96, 17, "400", "#64748b"))
    updated = meta.get("updated")
    if updated:
        parts.append(svg_text([f"source: schema.yaml · {updated}"], CANVAS_W - 265, 42, 12, "600", "#94a3b8"))

    if groups:
        parts.append('<g id="groups">')
        for group in groups:
            parts.append(group_svg(group, boxes))
        parts.append("</g>")

    parts.append('<g id="edges">')
    for edge in edges:
        parts.append(edge_svg(edge, boxes, categories, nodes_by_id))
    parts.append("</g>")

    parts.append('<g id="nodes">')
    for node in nodes:
        parts.append(node_svg(node, boxes[str(node["id"])], categories))
    parts.append("</g>")
    parts.append("</svg>")
    return "\n".join(parts)


def write_html(svg: str, path: pathlib.Path) -> None:
    path.write_text(
        "<!doctype html><meta charset='utf-8'><title>Architecture Diagram</title>"
        "<style>body{margin:0;background:#f8fafc}svg{display:block;max-width:100%;height:auto;margin:auto}</style>"
        + svg,
        encoding="utf-8",
    )


def maybe_write_png(svg_path: pathlib.Path, png_path: pathlib.Path) -> bool:
    try:
        import cairosvg  # type: ignore
    except ImportError:
        return False
    cairosvg.svg2png(url=str(svg_path), write_to=str(png_path), output_width=CANVAS_W)
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--schema", default="schema.yaml")
    parser.add_argument("--out-dir", default=".")
    parser.add_argument("--png", action="store_true", help="also render diagram.png if cairosvg is installed")
    args = parser.parse_args()

    schema_path = pathlib.Path(args.schema)
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    schema = load_schema(schema_path)
    svg = render_svg(schema)

    svg_path = out_dir / "diagram.svg"
    html_path = out_dir / "diagram.html"
    png_path = out_dir / "diagram.png"
    svg_path.write_text(svg, encoding="utf-8")
    write_html(svg, html_path)
    rendered_png = maybe_write_png(svg_path, png_path) if args.png else False

    print(f"wrote {svg_path}")
    print(f"wrote {html_path}")
    if args.png:
        if rendered_png:
            print(f"wrote {png_path}")
        else:
            print("skipped diagram.png: install cairosvg or run with `uv run --with cairosvg`")


if __name__ == "__main__":
    main()
