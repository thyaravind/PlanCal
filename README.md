# Plancal

Plancal is a native SwiftUI planner for iOS, iPadOS, and macOS 26. It combines Markdown notes, tasks across five planning horizons, multi-day events, Apple Calendar integration, iCloud sync, and a configurable morning brief.

## What is included

- Configurable day, week, month, quarter, and year planning horizons (days, weeks, and months are shown by default)
- Inline quick task creation and in-place task editing within each planning period
- Automatic carry-forward of unfinished work while preserving its original period
- Independent and period-specific WYSIWYG Markdown notes with Markdown typing shortcuts
- All-day, timed, single-day, multi-day, and recurring events
- Full EventKit access to show Apple Calendar events and sync Plancal events
- A local notification summary at 8:00 AM by default, including overdue work
- SwiftData persistence configured for private CloudKit sync
- Adaptive Liquid Glass navigation for iPhone, iPad, and Mac with hover-aware pointer interactions
- A consistent [Phosphor](https://github.com/phosphor-icons/swift) icon language for navigation, planning horizons, tasks, calendar details, and Markdown tools

## Requirements

- Xcode 26.4 or newer
- iOS/iPadOS 26.0 or macOS 26.0
- An Apple Developer team for device installation and CloudKit

## First run

1. Open `Plancal.xcodeproj` in Xcode.
2. Select the **Plancal** target and choose your development team under Signing & Capabilities.
3. Confirm that the App ID `app.plancal.native` and iCloud container `iCloud.app.plancal.native` exist for that team.
4. Run the app and grant notifications and full calendar access when prompted.

If CloudKit cannot initialize, Plancal opens a local SwiftData store and explains the fallback in Settings instead of crashing.

## Verification

```sh
xcodebuild -project Plancal.xcodeproj -scheme Plancal \
  -destination 'platform=macOS,arch=arm64' build-for-testing

xcodebuild -project Plancal.xcodeproj -scheme Plancal \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

These commands compile the app and test bundles without launching Plancal. The test suite covers planning-period boundaries, carry-forward semantics, completed-task behavior, and in-memory SwiftData persistence.
