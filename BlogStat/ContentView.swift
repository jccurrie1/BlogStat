import SwiftUI
import Observation
import OSLog

private let monitorLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BlogStat", category: "Monitor")

@MainActor
@Observable
final class Monitor {
    enum Status { case up, down, unknown }
    var status: Status = .unknown
    var lastChecked: Date? = nil

    private let url = URL(string: "https://www.jaredcurrie.com/")!
    var siteName: String {
        if let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return url.absoluteString
    }
    private var task: Task<Void, Never>?

    func start() {
        monitorLogger.log("Starting monitor loop")
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                await check()
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30s
            }
        }
    }

    func stop() {
        monitorLogger.log("Stopping monitor loop")
        task?.cancel()
    }

    func check() async {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 5
        req.setValue("BlogStat/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                if (200...399).contains(http.statusCode) {
                    status = .up
                } else {
                    status = .down
                }
            } else {
                monitorLogger.error("Response was not HTTPURLResponse")
                status = .down
            }
        } catch {
            monitorLogger.error("GET request failed: \(error.localizedDescription, privacy: .public)")
            status = .down
        }

        monitorLogger.log("Status set to: \(String(describing: self.status), privacy: .public)")
        lastChecked = Date()
        if let t = lastChecked {
            monitorLogger.log("Last checked updated: \(t.timeIntervalSince1970, privacy: .public)")
        }
    }
}

struct MenuContent: View {
    @Environment(Monitor.self) private var monitor

    private var label: String {
        switch monitor.status {
        case .up: return "Up — \(monitor.siteName)"
        case .down: return "Down — \(monitor.siteName)"
        case .unknown: return "Checking… — \(monitor.siteName)"
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
                    monitorLogger.log("User tapped: Check now")
                    Task { await monitor.check() }
                }
                Button("Quit") {
                    monitorLogger.log("User tapped: Quit")
                    NSApp.terminate(nil)
                }
            }
        }
        .onAppear { monitorLogger.log("MenuContent appeared") }
        .task { monitor.start() }
    }
}
