# Upstream PR template — validatedpatterns/docs

Copy this body when opening a pull request to [validatedpatterns/docs](https://github.com/validatedpatterns/docs) to publish **Hybrid Mesh Platform** on [validatedpatterns.io](https://validatedpatterns.io).

**Maintainer doc index (this repo):** [DOC-INDEX.md](DOC-INDEX.md)

---

## PR title

`Add Hybrid Mesh Platform pattern documentation`

## PR body

```markdown
## Summary

Adds documentation for the **Hybrid Mesh Platform** Validated Pattern (Sandbox tier).

- Hub-spoke multi-cluster GitOps (ACM + dual PUSH/PULL)
- Skupper service interconnect, Industrial Edge on spokes
- OpenShift AI / MaaS, Developer Hub, ACS, observability stack

## Source

- Pattern repo: https://github.com/maximilianoPizarro/hybrid-mesh-platform
- Docs folder to copy: `docs/validatedpatterns-docs/` → `content/patterns/hybrid-mesh-platform/`
- Bill of materials: `docs/bill-of-materials.md`
- Validation guide: `docs/validation-guide.md`

## Checklist

- [ ] Front matter `repo_url` points to pattern repo
- [ ] `_index.md` nav_order does not conflict with existing patterns
- [ ] Images under `assets/images/` copied or linked
- [ ] Tier set to **Sandbox**
- [ ] Related patterns linked (multicloud-gitops, industrial-edge)

## Test plan

- [ ] `hugo server` or site preview renders architecture and getting-started pages
- [ ] Internal links resolve under `/patterns/hybrid-mesh-platform/`
```
