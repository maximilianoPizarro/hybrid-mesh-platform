# Validated Patterns docs PR (replace #686)

Copy `docs/validatedpatterns-docs/` into `validatedpatterns/docs/content/patterns/hybrid-mesh-platform/` on a branch from `main`.

Update front matter `repo_url` and links to point to `github.com/maximilianoPizarro/hybrid-mesh-platform`.

Close [validatedpatterns/docs#686](https://github.com/validatedpatterns/docs/pull/686) with a comment linking the new PR.

## PR body template

```
## Summary
- Adds Hybrid Mesh Platform as sandbox-tier VP pattern
- Implementation: https://github.com/maximilianoPizarro/hybrid-mesh-platform (fork of multicloud-gitops + migrated charts)
- Replaces docs-only PR #686 — now VP-conformant (clustergroup, ESO, managedClusterGroups)

## Test plan
- [ ] pattern.sh install on demo hub
- [ ] ACM east/west Available
- [ ] Site build `make build`
```
