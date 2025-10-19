import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "UpDot", category: "Monitor")

@MainActor
@Observable
final class Monitor {
    enum Status { case up, down, unknown }
    var status: Status = .unknown
    var lastChecked: Date? = nil

    private let url = URL(string: "https://www.jaredcurrie.com/")!
    private var task: Task<Void, Never>?

    func start() {
        logger.log("Starting monitor loop")
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                await check()
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30s
            }
        }
    }

    func stop() {
        logger.log("Stopping monitor loop")
        task?.cancel()
    }

    func check() async {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 5
        req.setValue("UpDot/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                if (200...399).contains(http.statusCode) {
                    status = .up
                } else {
                    status = .down
                }
            } else {
                logger.error("Response was not HTTPURLResponse")
                status = .down
            }
        } catch {
            logger.error("GET request failed: \(error.localizedDescription, privacy: .public)")
            status = .down
        }

        logger.log("Status set to: \(String(describing: self.status), privacy: .public)")
        lastChecked = Date()
        if let t = lastChecked {
            logger.log("Last checked updated: \(t.timeIntervalSince1970, privacy: .public)")
        }
    }
}

struct MenuContent: View {
    @Environment(Monitor.self) private var monitor

    private var label: String {
        switch monitor.status {
        case .up: return "Up"
        case .down: return "Down"
        case .unknown: return "Checking…"
        }
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                if let t = monitor.lastChecked {
                    Text("Last checked: \(t.formatted(date: .omitted, time: .standard))")
                }
                Divider()
                Button("Check now") {
                    logger.log("User tapped: Check now")
                    Task { await monitor.check() }
                }
                Button("Quit") {
                    logger.log("User tapped: Quit")
                    NSApp.terminate(nil)
                }
            }
        }
        .onAppear { logger.log("MenuContent appeared") }
        .task { monitor.start() }
    }
}

@main
struct UpDotApp: App {
    @State private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(monitor)
                .onAppear { logger.log("MenuBarExtra content appeared") }
        } label: {
            Image(systemName: monitor.status == .up ? "checkmark.circle.fill" :
                                 monitor.status == .down ? "xmark.circle.fill" :
                                                           "questionmark.circle.fill")
        }
    }
}
