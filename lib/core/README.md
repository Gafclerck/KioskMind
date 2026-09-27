# lib/core

Shared, cross-feature code only.

Put something here only when at least two features genuinely need it. Anything
used by a single feature stays inside that feature.

Planned subfolders are described in `docs/ARCHITECTURE.md`: `di`, `constants`,
`errors`, `network`, `theme`, `localization`, `routing`, `usecase`,
`voice_services`, `widgets`.

They are intentionally not created yet. Do not add empty folders or placeholder
abstractions ahead of the code that needs them.
