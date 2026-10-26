# Calendar rollover and notes editing completion

## Metadata

- Timestamp: 2026-08-11T16:10:40Z
- Agent name: unknown-agent
- Model: GPT-5 Codex
- Launcher: Codex Desktop
- Workspace: repo root
- Environment: Darwin arm64; zsh
- Git: branch `main`; base commit `9e05829894f7`; dirty with the issue implementation and completion artifacts
- Issue source: user description covering calendar period rollover, app-menu navigation from an open note, independent-note autosave, and multi-line block formatting

## Issue summary

Calendar panels could remain on a previous current period after time advanced, split-view app navigation did not pop an open note editor, independent notes required explicit saving, and block formatting only affected one line of a multi-line selection.

## Status

PASS

## Requirements summary

### 1. Advance calendar panels with the current period

- Status: PASS
- Evidence: `CurrentPeriodAnchorResolver` advances an anchor only when it represented the previously current period, preserving explicit historical/future browsing.
- Test status: `PlanningScaleTests` covers daily rollover, monthly rollover, and preservation of a browsed period; all passed in the macOS test run.

### 2. Keep the app menu usable from an open note

- Status: PASS
- Evidence: split-view sidebar selection now resets the detail navigation identity before showing the selected app section, including when reselecting Notes.
- Test status: the updated root navigation compiled in the macOS build and full macOS test run.

### 3. Autosave independent notes and remove their Save action

- Status: PASS
- Evidence: independent note drafts debounce persistence, flush on disappearance, avoid creating empty records, update existing records without duplication, and omit the Save toolbar action. Period-assigned notes retain explicit Save behavior.
- Test status: three new `PersistenceControllerTests` covering create, empty-draft suppression, and update-without-duplicate passed.

### 4. Apply block formatting to every selected line

- Status: PASS
- Evidence: headings, bulleted lists, numbered lists, checklists, and block quotes now transform the complete selected line range in both native macOS and CodeMirror/WebKit editors. Reapplying a style toggles it off across the selection, and list conversion avoids stacked markers.
- Test status: four `MarkdownBlockFormatterTests` and the headless editor UI multi-line checklist/conversion checks passed.

## Implementation summary

### Files changed or added

- `Plancal/Models/PlanningScale.swift`
- `Plancal/Resources/MarkdownEditor.html`
- `Plancal/Services/MarkdownBlockFormatter.swift`
- `Plancal/Services/NoteEditorPersistence.swift`
- `Plancal/Views/Components/RichMarkdownEditor.swift`
- `Plancal/Views/Editors/NoteEditor.swift`
- `Plancal/Views/PlannerView.swift`
- `Plancal/Views/RootView.swift`
- `PlancalTests/MarkdownBlockFormatterTests.swift`
- `PlancalTests/PersistenceControllerTests.swift`
- `PlancalTests/PlanningScaleTests.swift`
- `WebEditor/src/editor.ts`
- `WebEditor/test/editor-ui.mjs`

### Files deleted

- None.

### Key changes

- Added current-period follower logic triggered by calendar-day changes and foreground activation.
- Reset the split-view detail stack on app-menu selection.
- Centralized independent-note draft persistence and debounced autosave behavior.
- Added a shared native block formatter and equivalent CodeMirror selection transform.
- Rebuilt the self-contained Markdown editor resource.

## Verification summary

### Verification steps executed

- `cd WebEditor && npm run check` — PASS
- `cd WebEditor && npm test` — PASS, 2 tests
- `cd WebEditor && npm run build` — PASS
- `cd WebEditor && npm run test:ui` — PASS
- `xcodebuild -quiet -project Plancal.xcodeproj -scheme Plancal -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` — PASS
- `xcodebuild -quiet -project Plancal.xcodeproj -scheme Plancal -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test` — PASS, all listed suites and cases passed
- `git diff --check` — PASS
- `xcodebuild -quiet -project Plancal.xcodeproj -scheme Plancal -configuration Debug -destination 'platform=iOS Simulator,id=<simulator-id>' CODE_SIGNING_ALLOWED=NO build` — NOT RUNNABLE because the installed Xcode environment has no eligible iOS simulator runtime

### Test execution results

- TypeScript type checking passed.
- Static WebEditor tests passed: 2/2.
- Headless browser editor interaction tests passed, including multi-line checklist formatting, toggling, and list conversion.
- Full macOS XCTest suite passed, including all new rollover, autosave, and formatting cases.
- No test failures occurred.

### Manual verification

- No app or simulator was launched, to avoid taking focus or controlling the user's running applications.

## Notes

- The calendar follows a rollover only when the old anchor was the prior current period; intentional browsing is not overwritten.
- Autosave is limited to independent notes as requested. Period notes continue to use explicit Save semantics.
- Empty new independent-note pages do not create database records.
- The bundled editor HTML was regenerated from `WebEditor/src/editor.ts`.
- The local Xcode installation reported no eligible iOS runtime, so iOS compilation could not be repeated in this environment; shared Swift logic, WebKit editor behavior, and macOS compilation/tests passed.

## Blockers

- None for implementation. Installing an iOS simulator runtime is required only to repeat the unavailable iOS build verification locally.
