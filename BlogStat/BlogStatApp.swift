import SwiftUI
import OSLog

private let appLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BlogStat", category: "App")

@main
struct BlogStatApp: App {
    @State private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(monitor)
                .onAppear { appLogger.log("MenuBarExtra content appeared") }
        } label: {
            Image(systemName: monitor.status == .up ? "checkmark.circle.fill" :
                                 monitor.status == .down ? "xmark.circle.fill" :
                                                           "questionmark.circle.fill")
        }
    }
}

