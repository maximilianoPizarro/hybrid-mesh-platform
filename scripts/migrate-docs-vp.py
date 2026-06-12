#!/usr/bin/env python3
"""Migrate legacy docs to docs/validatedpatterns-docs/ with VP conversion rules."""

from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(__file__).resolve().parents[2] / "platform-hub-spoke-config" / "docs"
DEST = ROOT / "docs" / "validatedpatterns-docs"

REPLACEMENTS = [
    (r"platform-hub-spoke-config", "hybrid-mesh-platform"),
    (
        r"maximilianopizarro\.github\.io/platform-hub-spoke-config",
        "validatedpatterns.io/patterns/hybrid-mesh-platform",
    ),
    (r"components/([a-z0-9-]+)", r"charts/all/\1"),
    (r"helm upgrade --install field-content \.", "./pattern.sh install"),
    (r"helm install platform-hub-spoke \.", "./pattern.sh install"),
    (r"`east/`", "`charts/region/east`"),
    (r"`west/`", "`charts/region/west`"),
    (r"values-east\.yaml", "charts/region/east/values.yaml"),
    (r"values-west\.yaml", "charts/region/west/values.yaml"),
    (r"values-hub\.yaml", "charts/region/hub/values.yaml"),
    (r"industrial-edge-spoke", "fleet-spoke-push"),
    (r"layout: default\n", ""),
    (r"nav_order: \d+\n", ""),
    (r"description: .+\n", ""),
]

TOP_LEVEL = [
    "getting-started.md",
    "architecture.md",
    "gitops-deployment-chain.md",
    "rhdp-field-content.md",
    "deploy-acm-gitops.md",
    "region-strategy.md",
    "scaffolding.md",
    "hub-gateway.md",
    "industrial-edge.md",
    "observability.md",
    "service-interconnect.md",
    "annotations-reference.md",
    "troubleshooting.md",
]


def to_hugo(content: str, title: str, weight: int) -> str:
    content = re.sub(r"^---\n.*?---\n", "", content, count=1, flags=re.DOTALL)
    for pattern, repl in REPLACEMENTS:
        content = re.sub(pattern, repl, content, flags=re.MULTILINE | re.IGNORECASE)
    return f"---\ntitle: {title}\nweight: {weight}\n---\n\n{content.strip()}\n"


def main() -> None:
    if not SOURCE.is_dir():
        print(f"Source docs not found: {SOURCE}")
        return

    DEST.mkdir(parents=True, exist_ok=True)
    weight = 2
    for name in TOP_LEVEL:
        src = SOURCE / name
        if not src.exists():
            continue
        raw = src.read_text(encoding="utf-8")
        title_match = re.search(r"^#\s+(.+)$", raw, re.MULTILINE)
        title = title_match.group(1) if title_match else name.replace("-", " ").title()
        (DEST / name).write_text(to_hugo(raw, title, weight), encoding="utf-8")
        weight += 1
        print(f"  migrated {name}")

    products_src = SOURCE / "products"
    products_dest = DEST / "products"
    if products_src.is_dir():
        products_dest.mkdir(exist_ok=True)
        for md in products_src.glob("*.md"):
            raw = md.read_text(encoding="utf-8")
            title = md.stem.replace("-", " ").title()
            (products_dest / md.name).write_text(
                to_hugo(raw, title, weight), encoding="utf-8"
            )
            weight += 1
            print(f"  migrated products/{md.name}")

    assets_src = SOURCE / "assets"
    assets_dest = DEST / "assets"
    if assets_src.is_dir():
        if assets_dest.exists():
            shutil.rmtree(assets_dest)
        shutil.copytree(assets_src, assets_dest)
        print("  copied docs/assets/")

    workshop_dest = DEST / "workshop"
    workshop_dest.mkdir(exist_ok=True)
    (workshop_dest / "_index.md").write_text(
        "---\ntitle: Hybrid Mesh AI Workshop\nweight: 50\n---\n\n"
        "Live lab content: [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai).\n",
        encoding="utf-8",
    )
    print("  wrote workshop/_index.md")


if __name__ == "__main__":
    main()
