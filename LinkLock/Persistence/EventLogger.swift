import Foundation

// MARK: - Event Types

enum EventType: String, Codable {
    case sessionStart    = "sessionStart"
    case canonicalLocked = "canonicalLocked"
    case blocked         = "blocked"
    case downloadBlocked = "downloadBlocked"
    case sessionEnd      = "sessionEnd"
}

// MARK: - Log Event

private struct LogEvent: Encodable {
    let ts: String
    let session: String
    let event: String
    var url: String?
    var reason: String?
    var details: String?
}

// MARK: - EventLogger

/// Appends structured JSONL records to Documents/linklock-events.jsonl.
/// Thread-safe via a dedicated serial queue.
final class EventLogger {

    static let shared = EventLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.linklock.logger", qos: .utility)
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("linklock-events.jsonl")
    }

    // MARK: - Public API

    func log(
        _ eventType: EventType,
        sessionID: UUID?,
        url: URL? = nil,
        reason: BlockReason? = nil,
        details: String? = nil
    ) {
        let event = LogEvent(
            ts: iso8601.string(from: Date()),
            session: sessionID?.uuidString ?? "none",
            event: eventType.rawValue,
            url: url?.absoluteString,
            reason: reason?.rawValue,
            details: details
        )
        queue.async { [weak self] in
            self?.append(event)
        }
    }

    // MARK: - Private

    private func append(_ event: LogEvent) {
        guard let data = try? JSONEncoder().encode(event),
              let line = String(data: data, encoding: .utf8) else { return }
        let lineWithNewline = line + "\n"
        guard let lineData = lineWithNewline.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(lineData)
                try? handle.close()
            }
        } else {
            try? lineData.write(to: fileURL, options: .atomic)
        }
    }

    /// Returns the file path for developer access (e.g. share via Files app).
    var logFilePath: String { fileURL.path }
}
