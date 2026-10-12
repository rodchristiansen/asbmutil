# asbmutil

## Worktrees

Create development worktrees **inside this repo** at `./.worktrees/<name>` — never as sibling `<repo>.worktree` folders next to it. Use the global `git wt` alias, which resolves the repo root and places the worktree under `.worktrees/` from any subdirectory:

```bash
git wt <name> [branch]
```

That runs `git worktree add .worktrees/<name> [branch]`. Keep `/.worktrees/` listed in this repo's `.gitignore`.

## Apple API releases

Apple ships School Manager (1.x) and Business (2.x) API releases on its own schedule. `docs/apple-api/coverage.json` records every release, endpoint and enum value Apple documents, with our status for each endpoint; `docs/apple-api/COVERAGE.md` is rendered from it. A weekly GitHub Action opens an `apple-api` issue when Apple's docs change.

Check for new releases before starting API work:

```bash
scripts/apple-api-watch.py check
```

When Apple has shipped something new, fold it into the record, then set `status` (`done` with `where`, `todo`, or `skip` with `note`) on each new endpoint and re-render:

```bash
scripts/apple-api-watch.py update
scripts/apple-api-watch.py render
```

When you implement an endpoint, mark it `done` in the same PR. New audit event types also go in `AuditEventCatalog` (`Sources/core/Models/AuditEvent.swift`).
