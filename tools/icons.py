"""Compile the repository's simple SVG icons into scalable Roblox UI primitives."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET


def compile_icons(directory: Path) -> str:
    icons = {}
    for path in sorted(directory.glob("*.svg")):
        root = ET.fromstring(path.read_text(encoding="utf-8"))
        if root.get("viewBox") != "0 0 24 24" or root.get("fill") != "none":
            raise ValueError(f"{path}: icons require viewBox 0 0 24 24 and fill=none")
        shapes = []
        for element in root:
            tag = element.tag.split("}")[-1]
            width = float(element.get("stroke-width", root.get("stroke-width", "1.8")))
            def n(key, default="0"):
                return float(element.get(key, default))
            if tag == "line":
                shapes.append(["line", n("x1"), n("y1"), n("x2"), n("y2"), width])
            elif tag == "polyline":
                numbers = [float(x) for x in element.get("points", "").replace(",", " ").split()]
                if len(numbers) % 2 or len(numbers) < 4:
                    raise ValueError(f"{path}: invalid polyline")
                points = list(zip(numbers[::2], numbers[1::2]))
                for start, end in zip(points, points[1:]):
                    shapes.append(["line", *start, *end, width])
            elif tag == "rect":
                shapes.append(["rect", n("x"), n("y"), n("width"), n("height"), n("rx"), width])
            elif tag == "circle":
                shapes.append(["circle", n("cx"), n("cy"), n("r"), width])
            else:
                raise ValueError(f"{path}: unsupported SVG primitive {tag}")
        icons[path.stem] = shapes
    def lua(value):
        if isinstance(value, dict):
            return "{" + ",".join("[" + json.dumps(k) + "]=" + lua(v) for k, v in value.items()) + "}"
        if isinstance(value, list):
            return "{" + ",".join(lua(x) for x in value) + "}"
        return json.dumps(value)
    return "local SVG_ICONS = " + lua(icons) + "\n"
