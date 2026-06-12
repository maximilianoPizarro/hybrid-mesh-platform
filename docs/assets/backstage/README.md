---
layout: default
title: Backstage Assets
parent: Getting Started
nav_exclude: true
---

# Backstage assets

Static catalog entities for Red Hat Developer Hub. Software templates are managed via Gitea (local SCM), not GitHub Pages.

## Catalog entities

| Asset | Description |
| ----- | ----------- |
| `catalog/industrial-edge-system.yaml` | System, Domain, Components, APIs for Industrial Edge |
| `catalog/users.yaml` | User/Group entities for RHDH |
| `catalog/location.yaml` | Location index for catalog discovery |

These files are mounted into the Developer Hub pod via ConfigMaps defined in `components/developer-hub/templates/all.yaml`.

## Related docs

- [Developer Hub product page]({{ site.baseurl }}/products/developer-hub.html)
- [Annotations reference — Backstage catalog]({{ site.baseurl }}/annotations-reference.html#backstage-catalog-annotations)
