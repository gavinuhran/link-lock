import Foundation

// MARK: - Session State Machine

enum SessionState: Equatable {
    case idle
    case resolving(originalURL: URL)
    case locked(canonicalURL: URL)
    case ended
}

// MARK: - Session

struct Session {
    let id: UUID
    let originalURL: URL
    var canonicalURL: URL?
    let startTime: Date
    var blockedAttempts: Int = 0

    init(id: UUID = UUID(), originalURL: URL, startTime: Date = Date()) {
        self.id = id
        self.originalURL = originalURL
        self.startTime = startTime
    }
}
