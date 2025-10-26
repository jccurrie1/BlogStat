# BlogStat

BlogStat is a lightweight macOS menu bar utility that keeps an eye on a single website and reports whether it is up, down, or still being checked. It is designed for personal monitoring and runs quietly from the menu bar.

## Highlights
- Polls `https://www.jaredcurrie.com/` every 30 seconds using `URLSession`.
- Shows an inline menubar icon (`checkmark`, `xmark`, or `questionmark`) with a matching dropdown label.
- Manual “Check now” action plus timestamp of the last successful check.
- Logs monitor and UI events with `OSLog` for quick debugging in Console.app.

## Requirements
- macOS 15 (Sequoia) or later.
- Xcode 16.0+ (Swift 5.10, SwiftUI menu bar extras).

## Getting Started
1. Open `BlogStat.xcodeproj` in Xcode.
2. Select the **BlogStat** scheme.
3. Build & Run; Xcode will attach the menubar extra to the current user session.

> **Note:** If you see sandbox errors when building from the command line, clear `~/Library/Developer/Xcode/DerivedData/` or run a build from inside Xcode to regenerate the derived data folder.

## Status Indicators
| State    | Icon                      | What it means                                      |
|----------|---------------------------|----------------------------------------------------|
| Up       | `checkmark.circle.fill`   | HTTP status code 200–399                           |
| Down     | `xmark.circle.fill`       | Non-success HTTP status or request/logging errors  |
| Unknown  | `questionmark.circle.fill`| Waiting on the first request or monitor cancelled  |

## Project Layout
```
BlogStat/
├─ Assets.xcassets/          # App icon & accent color
├─ BlogStatApp.swift         # @main entry point for the menu bar extra
└─ ContentView.swift         # Monitor model + menu UI
BlogStatTests/               # Swift Testing placeholder target
BlogStatUITests/             # XCTest UI harness and launch snapshot test
BlogStat-Info.plist          # Generated Info.plist for the macOS target
```

## Customizing the Monitor
- **URL** – Update the `url` constant inside `Monitor` (`BlogStat/ContentView.swift`).
- **Polling interval** – Adjust the `Task.sleep` duration in `Monitor.start()`.
- **User-Agent** – Change the value set on the `URLRequest` in `Monitor.check()`.

## Logging
Two `OSLog` categories are used:
- `category: "Monitor"` (`ContentView.swift`) tracks network activity and state transitions.
- `category: "App"` (`BlogStatApp.swift`) reports menu bar extra lifecycle events.

Search for log entries in Console.app by filtering on the subsystem `Personal.BlogStat` or the categories above.

## Troubleshooting
- Ensure the target is code signed with a team that supports hardened runtime (enabled by default in the project settings).
- If the menu bar icon does not appear, confirm the app is marked as a menubar-only app (`LSUIElement = YES` in `BlogStat-Info.plist`).

## Roadmap Ideas
- Allow multiple URLs with per-site status.
- Display request latency or HTTP status code in the menu.
- Persist the last-known status across launches.
- Surface notifications when the status flips.

Feel free to adapt the app to match your own monitoring needs.
