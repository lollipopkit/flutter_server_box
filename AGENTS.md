# Repository Guidelines

## Project Structure & Module Organization

- `lib/` is the main Flutter app code:
  - `core/` shared utilities, extensions, routes
  - `data/model/`, `data/provider/`, `data/store/` for models, Riverpod state, and local storage (SqliteStore/SQLCipher)
  - `view/page/`, `view/widget/` for screens and reusable UI
  - `l10n/` ARB sources and `generated/l10n/` generated localization code
- `test/` contains parser/model/unit tests (mostly `*_test.dart`).
- `docs/` hosts the Astro/Starlight documentation site.
- `packages/` contains local dependency forks/submodules (for example `dartssh2`, `xterm`, `fl_lib`, `fl_build`).

## Build, Test, and Development Commands

- `flutter pub get`: install dependencies.
- `flutter run` or `flutter run -d <device-id>`: run locally.
- `dart run build_runner build --delete-conflicting-outputs`: regenerate Freezed/JSON/Hive/Riverpod code.
- `flutter gen-l10n`: regenerate localization from `lib/l10n/*.arb`.
- `flutter analyze lib test`: static checks (matches CI scope).
- `flutter test`: run all tests.
- `dart run fl_build -p <android|ios|macos|linux|windows>`: platform build pipeline.

## Coding Style & Naming Conventions

- Follow `analysis_options.yaml` + `flutter_lints`.
- Use package imports and keep imports ordered (`directives_ordering`).
- Prefer single quotes and explicit return types where linted.
- Naming: files `snake_case.dart`, types `UpperCamelCase`, members `lowerCamelCase`.
- Do not hand-edit generated files (`*.g.dart`, `*.freezed.dart`); update source annotations and regenerate.
- **Never run code formatting commands** - The codebase has specific formatting that should not be changed
- **Always run code generation** after modifying models with annotations (freezed, json_serializable, hive, riverpod)
- Generated files (`*.g.dart`, `*.freezed.dart`) should not be manually edited
- USE dependency injection via GetIt for services like Stores, Services and etc.
- Generate all l10n files using `flutter gen-l10n` command after modifying ARB files.
- USE `hive_ce` not `hive` package for Hive integration.
  - Which no need to config `HiveField` and `HiveType` manually.
- USE widgets and utilities from `fl_lib` package for common functionalities.
  - Such as `CustomAppBar`, `context.showRoundDialog`, `Input`, `Btnx.cancelOk`, etc.
  - You can use context7 MCP to search `lppcg fl_lib KEYWORD` to find relevant widgets and utilities.
- USE `libL10n` and `l10n` for localization strings.
  - `libL10n` is from `fl_lib` package, and `l10n` is from this project.
  - Before adding new strings, check if it already exists in `libL10n`.
  - Prioritize using strings from `libL10n` to avoid duplication, even if the meaning is not 100% exact, just use the substitution of `libL10n`.
- Split UI into Widget build, Actions, Utils. use `extension on` to achieve this

## Testing Guidelines

- Use `flutter_test`/`package:test`.
- Name tests as `*_test.dart`; keep them under `test/` and close to feature domains.
- Prefer focused test runs first (for example `flutter test test/cpu_test.dart`), then full `flutter test`.
- For parser/model changes, add or update corresponding tests before opening a PR.

## Commit & Pull Request Guidelines

- Recent history follows concise conventional prefixes: `fix:`, `feat(scope):`, `chore:`, `ref:`, `bump:`.
- Keep commits scoped and descriptive (example: `fix(container): handle sudo parse result`).
- PRs targeting `main` should include: change summary, linked issue/discussion, and verification steps run.
- For UI changes, attach screenshots; for bug fixes, include reproducible steps and relevant logs.

## Security & Configuration Tips

- Never commit secrets, keys, or signing artifacts; CI release pulls sensitive files from GitHub Secrets.
- Review dependency and submodule updates carefully, especially cross-platform build impact.
