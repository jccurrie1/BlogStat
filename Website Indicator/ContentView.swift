import Combine
import SwiftUI
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "UpDot", category: "Monitor")

@MainActor
final class Monitor: ObservableObject {
    enum Status { case up, down, unknown }
    @Published var status: Status = .unknown
    @Published var lastChecked: Date? = nil

    private let url = URL(string: "https://jaredcurrie.com")!
    private var altURL: URL? {
        guard let host = url.host, !host.hasPrefix("www.") else { return nil }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.host = "www." + host
        return comps?.url
    }
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
        logger.log("Beginning check for URL: \(self.url.absoluteString, privacy: .public)")
        req.httpMethod = "HEAD"
        logger.log("Attempting HEAD request")
        req.timeoutInterval = 5
        req.setValue("UpDot/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                logger.log("HEAD response status: \(http.statusCode)")
                if (200...399).contains(http.statusCode) {
                    status = .up
                } else if http.statusCode == 405 {
                    logger.log("HEAD not allowed (405). Falling back to GET")
                    var getReq = URLRequest(url: url)
                    getReq.httpMethod = "GET"
                    getReq.timeoutInterval = 5
                    getReq.setValue("UpDot/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")
                    let (_, getResp) = try await URLSession.shared.data(for: getReq)
                    if let http = getResp as? HTTPURLResponse {
                        logger.log("GET response status: \(http.statusCode)")
                        if (200...399).contains(http.statusCode) {
                            status = .up
                        } else {
                            status = .down
                        }
                    } else {
                        logger.error("GET response was not HTTPURLResponse")
                        status = .down
                    }
                } else {
                    status = .down
                }
            } else {
                logger.error("HEAD response was not HTTPURLResponse")
                status = .down
            }
        } catch {
            logger.error("HEAD request failed: \(error.localizedDescription, privacy: .public)")

            // If the error is a DNS resolution failure (-1003), try an alternate host with a "www." prefix
            if let urlErr = error as? URLError, urlErr.code == .cannotFindHost, let alt = altURL {
                logger.log("HEAD failed: cannot find host. Retrying with alternate host: \(alt.absoluteString, privacy: .public)")
                do {
                    var altReq = URLRequest(url: alt)
                    altReq.httpMethod = "HEAD"
                    altReq.timeoutInterval = 5
                    altReq.setValue("UpDot/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")
                    let (_, altResp) = try await URLSession.shared.data(for: altReq)
                    if let http = altResp as? HTTPURLResponse {
                        logger.log("ALT HEAD response status: \(http.statusCode)")
                        if (200...399).contains(http.statusCode) {
                            status = .up
                            lastChecked = Date()
                            if let t = lastChecked { logger.log("Last checked updated: \(t.timeIntervalSince1970, privacy: .public)") }
                            return
                        }
                    } else {
                        logger.error("ALT HEAD response was not HTTPURLResponse")
                    }
                } catch {
                    logger.error("ALT HEAD failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            do {
                var getReq = URLRequest(url: url)
                getReq.httpMethod = "GET"
                getReq.timeoutInterval = 5
                getReq.setValue("UpDot/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")
                logger.log("Attempting GET fallback")
                let (_, getResp) = try await URLSession.shared.data(for: getReq)
                if let http = getResp as? HTTPURLResponse {
                    logger.log("GET response status: \(http.statusCode)")
                    if (200...399).contains(http.statusCode) {
                        status = .up
                    } else {
                        status = .down
                    }
                } else {
                    logger.error("GET response was not HTTPURLResponse")
                    status = .down
                }
            } catch {
                logger.error("GET fallback failed: \(error.localizedDescription, privacy: .public)")

                // If GET also failed due to cannotFindHost, try GET against the alternate host (www.) once
                if let urlErr = error as? URLError, urlErr.code == .cannotFindHost, let alt = altURL {
                    logger.log("GET failed: cannot find host. Retrying ALT GET: \(alt.absoluteString, privacy: .public)")
                    do {
                        var altGetReq = URLRequest(url: alt)
                        altGetReq.httpMethod = "GET"
                        altGetReq.timeoutInterval = 5
                        altGetReq.setValue("UpDot/1.0 (+macOS)", forHTTPHeaderField: "User-Agent")
                        let (_, altGetResp) = try await URLSession.shared.data(for: altGetReq)
                        if let http = altGetResp as? HTTPURLResponse {
                            logger.log("ALT GET response status: \(http.statusCode)")
                            if (200...399).contains(http.statusCode) {
                                status = .up
                            } else {
                                status = .down
                            }
                        } else {
                            logger.error("ALT GET response was not HTTPURLResponse")
                            status = .down
                        }
                    } catch {
                        logger.error("ALT GET failed: \(error.localizedDescription, privacy: .public)")
                        status = .down
                    }
                } else {
                    status = .down
                }
            }
        }
        logger.log("Status set to: \(String(describing: self.status), privacy: .public)")
        lastChecked = Date()
        if let t = lastChecked {
            logger.log("Last checked updated: \(t.timeIntervalSince1970, privacy: .public)")
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var monitor: Monitor

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
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(monitor)
                .onAppear { logger.log("MenuBarExtra content appeared") }
        } label: {
            Image(systemName: monitor.status == .up ? "checkmark.circle.fill" :
                                 monitor.status == .down ? "xmark.circle.fill" :
                                                           "questionmark.circle.fill")
        }
    }
}
