#!/usr/bin/env python3
"""Split templates/all.yaml into per-resource template files."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARTS = ROOT / "charts" / "all"


def split_documents(content: str) -> list[str]:
    """Split multi-doc YAML preserving Helm template blocks."""
    docs: list[str] = []
    current: list[str] = []
    in_template = False
    for line in content.splitlines(keepends=True):
        if re.match(r"^\s*\{\{-?\s", line) or re.match(r"^\s*\{\{", line):
            in_template = True
        if line.strip() == "---" and current and not in_template:
            doc = "".join(current).strip()
            if doc:
                docs.append(doc)
            current = []
            continue
        current.append(line)
        if line.strip().endswith("-}}") or line.strip().endswith("}}"):
            in_template = False
    tail = "".join(current).strip()
    if tail:
        docs.append(tail)
    return docs


def doc_filename(doc: str, index: int) -> str:
    kind = ""
    name = ""
    for line in doc.splitlines():
        if line.startswith("kind:"):
            kind = line.split(":", 1)[1].strip().lower()
        if line.startswith("metadata:"):
            continue
        if line.strip().startswith("name:") and not name:
            raw = line.split(":", 1)[1].strip()
            if "{{" not in raw:
                name = re.sub(r"[^a-z0-9-]", "-", raw.lower())
    base = f"{kind}-{name}" if kind and name else f"resource-{index:02d}"
    return f"{base}.yaml"


def split_chart(chart_dir: Path, dry_run: bool = False) -> bool:
    all_yaml = chart_dir / "templates" / "all.yaml"
    if not all_yaml.exists():
        return False
    content = all_yaml.read_text(encoding="utf-8")
    docs = split_documents(content)
    if len(docs) <= 1:
        print(f"  skip {chart_dir.name}: single document")
        return False
    templates = chart_dir / "templates"
    names_used: dict[str, int] = {}
    for i, doc in enumerate(docs, 1):
        fname = doc_filename(doc, i)
        if fname in names_used:
            names_used[fname] += 1
            stem, ext = fname.rsplit(".", 1)
            fname = f"{stem}-{names_used[fname]}.{ext}"
        else:
            names_used[fname] = 0
        target = templates / fname
        if dry_run:
            print(f"  would write {target.name}")
        else:
            target.write_text(doc + "\n", encoding="utf-8")
    if not dry_run:
        all_yaml.unlink()
        print(f"  split {chart_dir.name} -> {len(docs)} files, removed all.yaml")
    return True


def helm_lint(chart_dir: Path) -> bool:
    r = subprocess.run(
        ["helm", "lint", str(chart_dir)],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        print(r.stdout, r.stderr, file=sys.stderr)
        return False
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--chart", action="append", help="Specific chart name")
    parser.add_argument("--skip-lint", action="store_true")
    args = parser.parse_args()

    charts = sorted(CHARTS.iterdir())
    if args.chart:
        charts = [CHARTS / c for c in args.chart]

    split_count = 0
    for chart_dir in charts:
        if not chart_dir.is_dir():
            continue
        if not (chart_dir / "Chart.yaml").exists():
            continue
        if split_chart(chart_dir, dry_run=args.dry_run):
            split_count += 1
            if not args.dry_run and not args.skip_lint:
                if not helm_lint(chart_dir):
                    print(f"WARN: helm lint failed for {chart_dir.name}", file=sys.stderr)

    print(f"Processed {split_count} charts")


if __name__ == "__main__":
    main()
