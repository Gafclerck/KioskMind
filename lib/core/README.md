# lib/core

Shared, cross-feature code only.

Put something here only when at least two features genuinely need it. Anything
used by a single feature stays inside that feature.

## Subfolders

| Folder | Responsibility |
|---|---|
| `di/` | Dependency injection service locator |
| `constants/` | Constant values, default thresholds |
| `errors/` | `Failure`, custom exceptions |
| `network/` | Connectivity checker, HTTP client |
| `theme/` | Shared theme and styles |
| `localization/` | i18n setup (FR/EN), translation delegate |
| `routing/` | Route configuration |
| `usecase/` | Common abstract `UseCase<Type, Params>` class |
| `voice_services/` | Raw technical adapters (multilingual STT/TTS), no business logic |
| `widgets/` | Shared UI widgets (status badges, buttons) |

The folders exist to fix the boundaries, not to be filled upfront. A folder with
no code yet is fine. Do not add placeholder abstractions ahead of the code that
needs them, and do not move a helper here before two features actually use it.
