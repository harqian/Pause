# Repository Guidelines

## Project Structure & Module Organization
macOS app source lives in `Pause/` with entry points such as `PauseApp.swift`, `ContentView.swift`, and state managers (`AppState.swift`, `ActivationScheduler.swift`). Reusable SwiftUI views are under `Views/` (`Views/Components`, `Views/Settings`), shared helpers sit in `Utilities/`, and bundled audio assets remain in `Resources/`. The Xcode definition is `Pause.xcodeproj`, while the marketing site resides in `website/` (Vite + Vue 3) with its entry at `website/src/main.ts`.

## Build, Test, and Development Commands
- `open Pause.xcodeproj` – launch the macOS app in Xcode for iterative work.
- `xcodebuild -project Pause.xcodeproj -scheme Pause -configuration Debug build` – CI-friendly build.
- `xcodebuild test -project Pause.xcodeproj -scheme Pause` – execute Swift Testing suites and UI hooks.
- `cd website && npm install` – install web dependencies (Node 20+).
- `cd website && npm run dev` – start the live-reload marketing site.
- `cd website && npm run build` – produce the static bundle; pair with `npm run lint` before shipping.

## Coding Style & Naming Conventions
Follow Swift 5 style with four-space indentation. Use `PascalCase` for types, `camelCase` for properties/functions, and prefer `struct`-based SwiftUI views plus `final class` managers (`AppState`, `GlobalHotkeyManager`). Keep string constants in `Settings` and persist via `UserDefaults`. Audio filenames in `Resources/` are lowercase without separators—mirror that when adding assets. The web site uses TypeScript + Vue; rely on `npm run format` (Prettier) and keep page-level components in `website/src/views`.

## Testing Guidelines
normal xcode testing

## Commit & Pull Request Guidelines
Project history favors terse, lower-case subject lines (e.g., `prevent scheduled activation resets`). Use the imperative mood, keep the summary under ~72 characters, and add context in the body when the change is non-trivial. Each PR should include: a concise change summary, validation notes (`xcodebuild test`, website lint/build output), linked issues, and macOS UI screenshots or screen recordings when visuals change. Request review only after local checks pass or you have posted blockers.

## Configuration Tips
Grant macOS Accessibility permissions on first launch so global hotkeys work. Keep entitlement updates mirrored in `Pause.entitlements`, and drop new ambient audio into `Pause/Resources/` so the build includes it. For the website, track environment variables in a `.env.local` ignored by git and document any new keys in the PR description.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
