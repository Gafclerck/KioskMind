# lib/features

One folder per feature. Every feature respects three layers:

```text
<feature>/
  presentation/   widgets, pages, state management
  domain/         entities, use cases, repository contracts
  data/           models, data sources, repository implementations
```

Dependencies flow inward: `presentation` and `data` depend on `domain`, and
`domain` depends on nothing from the outer layers.

Feature list and responsibilities: `docs/ARCHITECTURE.md`.

No feature is scaffolded yet. Create the three layers when implementing a
feature, not before.
