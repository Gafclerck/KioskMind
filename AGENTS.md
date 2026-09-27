# kiosk_mind - Agent Notes

Single Flutter **app** (not a monorepo, no packages/ dir). Flutter 3.44.6 stable / Dart 3.12.2,
pinned in `.metadata` to revision `ee80f08bbf`. Repo is on Windows `D:` (`/mnt/d/kiosk_mind` in
WSL); SDK is on `C:` (`/mnt/c/develop/flutter`).

## Run every Dart/Flutter command through `cmd.exe`

The Flutter SDK checkout on `/mnt/c` has **CRLF line endings in its bash scripts**, so invoking
the tool from WSL bash is broken:

```
$ flutter analyze
/mnt/c/develop/flutter/bin/internal/shared.sh: line 5: $'\r': command not found   # exit 127
```

`dart` is affected identically. Use the Windows-side invocation with a Windows path:

```bash
cmd.exe /c "cd /d D:\kiosk_mind && flutter analyze"
cmd.exe /c "cd /d D:\kiosk_mind && flutter test"
```

`git` and normal file editing work fine directly from WSL - only the Flutter/Dart tool needs
the bridge. A "command not found" here is an environment defect, **not** a broken project; do
not try to debug the code in response to it.

## Commands

| Task                        | Command (via the `cmd.exe` bridge above)                    |
| --------------------------- | ----------------------------------------------------------- |
| Lint / typecheck            | `flutter analyze`                                           |
| Tests                       | `flutter test`                                              |
| Single test                 | `flutter test test/widget_test.dart`                        |
| Single test by name         | `flutter test --plain-name "app builds and exposes its title"` |
| Format                      | `dart format lib test`                                     |
| Hot reload on a running app | `flutter run` then press `r`                                |

Verification order is `format` -> `analyze` -> `test`. All three pass on `feat/001-tooling`.

`flutter analyze` took **~170s on a cold run** before printing results. It is not hung; budget
for it and use a generous timeout rather than killing and retrying.

## Line endings: fixed on `feat/001-tooling`, not yet on `main`/`develop`

All 85 tracked files used to show as modified (4722 insertions / 4722 deletions) purely from
CRLF working-tree vs LF blobs, with no `.gitattributes` and no `core.autocrlf`. Root cause is
fixed by `.gitattributes` (`* text=auto eol=lf`) plus a one-time `git add --renormalize .`,
which changed **no** file content.

That fix lives on `feat/001-tooling`. Until it is merged into `develop` and `main`, those branches
still show the full phantom diff. If you see 85 modified files, check your branch before
debugging your own change, and use `git diff --stat` to separate real edits from churn. Do not
delete `.gitattributes`, and never commit the churn via `git add -A`.

## Architecture

Source of truth is `docs/ARCHITECTURE.md` (user-authored, in French). It defines the feature list
and the `core/` subfolders. Read it before adding a feature and do not invent a different layout.

Current state: `lib/main.dart` is a thin entry point, `lib/app.dart` is the root widget, and
`lib/core/` and `lib/features/` exist as documented boundaries but are **empty on purpose**.
There is no state management, routing, codegen, assets folder, or custom theming yet. The stock
`flutter create` counter demo has been removed.

Since no feature code exists, the architecture doc is the target to build toward, not a
convention to retrofit.

### Adding a feature

- Create `lib/features/<name>/{presentation,domain,data}` when you implement it, not before. Do
  not scaffold empty layers.
- `presentation` and `data` depend on `domain`; `domain` depends on neither.
- `core/` is only for code genuinely used by two or more features. No speculative abstractions
  and no placeholder classes.
- Add a dependency only when code actually needs it, and check Dart 3.12.2 compatibility first.
  Firebase, FCM, STT/TTS, i18n and Excel export are planned in the architecture doc but are
  **not installed**. Do not add them speculatively.
- `test/widget_test.dart` only smoke-tests the placeholder home. Point it at the first real
  feature once one exists.

## Platforms

All six scaffolds are checked in (`android`, `ios`, `linux`, `macos`, `web`, `windows`) and
`.metadata` tracks all six, so `flutter create --platforms` additions are a no-op here.

Android still uses the template identity `namespace`/`applicationId`
`com.example.kiosk_mind` (`android/app/build.gradle.kts`) - change it before any real
distribution. SDK levels are delegated to Flutter (`flutter.compileSdkVersion`,
`flutter.minSdkVersion`, `flutter.targetSdkVersion`), so don't hardcode them. Gradle wrapper
is 9.1.0. No platform build has been run in this repo yet - only `analyze` and `test` have been
verified green. Note that iOS/macOS cannot be built from this WSL environment at all, since
they need a macOS host with Xcode; run them from Windows/macOS instead.

## Other

- Lint set is stock `flutter_lints` 6.0.0 via `analysis_options.yaml`; no custom rules, so
  `flutter analyze` is the only style gate.
- `dart format lib test` is the formatter, but nothing enforces it locally. `.github/workflows/ci.yml`
  runs `flutter pub get`, `flutter analyze` and `flutter test` on Linux for pushes and PRs to
  `main` and `develop`. It does **not** check formatting, so run `dart format` yourself.
- `README.md` documents setup, commands, structure and the Git workflow.
- `.github/modernize/java-upgrade/` is gitignored (`**/*`) agent tooling with PowerShell and
  shell hook scripts - not project source, and safe to ignore.

# Project Rules

## Architecture

- Follow Clean Architecture with a feature-first structure.
- Every feature must respect the three layers:
  - `presentation`
  - `domain`
  - `data`

- Keep widgets small and focused. Move business logic outside widgets.
- Follow SOLID principles, especially Single Responsibility, Open/Closed, Interface Segregation, and Inversion of Control.
- Keep the code modular, reusable, maintainable, and loosely coupled.
- Shared functionality used across multiple features belongs in `core`.

## Git Workflow

- Never work directly on `main`.
- Never work directly on `develop`.
- Create a dedicated branch for every feature or isolated task.
- Complete and test the work before opening a Pull Request.
- Merge only through the appropriate Pull Request workflow.

### Branches

Use descriptive branch names:

```text
feature/<name>
fix/<name>
refactor/<name>
```

### Commits

- Every commit must have a conventional prefix.
- The message must be clear, precise, and concise.
- A commit message must never exceed one line.
- Keep each commit focused on one logical change.

Example:

```text
feat: add user authentication
fix: handle invalid login credentials
refactor: simplify auth state management
```

## Code Quality

- Avoid unnecessary complexity and duplication.
- Do not overload widgets with business or data logic.
- Reuse existing abstractions before creating new ones.
- Create shared abstractions in `core` only when they are genuinely cross-feature.
- Preserve the existing architecture and conventions when modifying code.

## Comments and Formatting

- Do not use em dashes (`—`). Use regular hyphens (`-`).
- Avoid decorative comment separators or repeated symbols.
- Comments must be concise, and meaningful.
- Prefer self-explanatory code over comments.
