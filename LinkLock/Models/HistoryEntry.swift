import Foundation

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let originalURL: URL
    let canonicalURL: URL
    let startTime: Date
    let endTime: Date
    let blockedAttempts: Int

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let d = Int(duration)
        if d < 60 { return "\(d)s" }
        let m = d / 60; let s = d % 60
        return String(format: "%d:%02d", m, s)
    }
}
