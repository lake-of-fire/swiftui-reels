# Repository Guidelines

## Project Structure & Module Organization
- `Sources/SwiftUIReels`: Core SwiftUI runtime, grouped into `Components`, `Streaming`, `Helpers`, and more; keep new modules aligned with these folders.
- `Examples/CLIExample` and `Examples/VideoViews`: Runnable templates demonstrating CLI usage and view compositions.
- `Scripts/GenerateTemplate`: Stencil-based templating CLI; add reusable blueprints and assets here.
- `Tests/SwiftUIReelsTests`: XCTest target; mirror source folder names and add new test files with `*Tests.swift`.

## Build, Test, and Development Commands
- `swift build --product SwiftUIReels` compiles the library for macOS 14+; run before submitting changes.
- `swift test` executes `SwiftUIReelsTests` and should pass locally; add `--enable-code-coverage` when verifying metrics.
- `swift run CLIExample --help` checks the example executable and validates ArgumentParser wiring.
- `swift run GenerateTemplate <TemplateName>` renders template scaffolds into the working directory; run from the repo root.

## Coding Style & Naming Conventions
- Use Swift 5.10 defaults: four-space indentation, trailing commas for multiline literals, `camelCase` for functions/properties, `PascalCase` for types.
- Prefer SwiftUI view builders over imperative updates; isolate side effects in helpers under `Helpers/`.
- Keep extensions in `Extensions/` scoped by feature and guarded with access control (`public` only when required).

## Testing Guidelines
- Use XCTest; place fixtures under `Tests/SwiftUIReelsTests/Fixtures` if needed and name test cases `<Feature>Tests`.
- Write focused tests per component and cover streaming/publishing flows via mock dependencies.
- Execute `swift test --filter <CaseName>` before pushing if only a subset changed.

## Commit & Pull Request Guidelines
- Follow existing history: short (≤72 char) imperative subject lines (e.g., `Add RTMP bitrate knob`); body optional but clarify behavior changes.
- Reference issues in the body with `Fixes #123` where applicable and describe user-facing impact.
- Pull requests should list testing performed, attach screenshots or video for UI-affecting changes, and request review from at least one maintainer.
