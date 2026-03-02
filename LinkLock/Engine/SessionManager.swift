import Foundation
import Combine

/// ObservableObject that drives all UI state for a single browsing session.
/// Owns the state machine: idle → resolving → locked → ended.
@MainActor
final class SessionManager: ObservableObject {

    // MARK: - Published State

    @Published var state: SessionState = .idle
    @Published var showBlockedOverlay = false
    @Published var lastBlockedURL: URL?
    @Published var lastBlockReason: BlockReason?

    // MARK: - Internal Session Record

    private(set) var currentSession: Session?

    // MARK: - Dependencies

    private let logger = EventLogger.shared
    private let history = HistoryStore.shared

    // MARK: - State Transitions

    /// Call when the user taps Open with a pasted URL.
    func startSession(url: URL) {
        let session = Session(originalURL: url)
        currentSession = session
        state = .resolving(originalURL: url)
        logger.log(.sessionStart, sessionID: session.id, url: url)
    }

    /// Call from WKNavigationDelegate.didCommitNavigation to lock the canonical URL.
    /// Idempotent — only transitions from .resolving.
    func lockCanonical(url: URL) {
        guard case .resolving = state else { return }
        currentSession?.canonicalURL = url
        state = .locked(canonicalURL: url)
        logger.log(.canonicalLocked, sessionID: currentSession?.id, url: url)
    }

    /// Call whenever a navigation or action is blocked.
    func recordBlocked(reason: BlockReason, url: URL?) {
        currentSession?.blockedAttempts += 1
        lastBlockedURL = url
        lastBlockReason = reason
        showBlockedOverlay = true
        logger.log(.blocked, sessionID: currentSession?.id, url: url, reason: reason)
    }

    /// Call when the user taps "Stay" on the blocked overlay.
    func dismissOverlay() {
        showBlockedOverlay = false
    }

    /// Call when the user taps "End Session" or navigates away.
    func endSession() {
        guard let session = currentSession else { return }

        let entry = HistoryEntry(
            id: session.id,
            originalURL: session.originalURL,
            canonicalURL: session.canonicalURL ?? session.originalURL,
            startTime: session.startTime,
            endTime: Date(),
            blockedAttempts: session.blockedAttempts
        )
        history.add(entry)
        logger.log(.sessionEnd, sessionID: session.id, url: session.canonicalURL)

        state = .ended
        currentSession = nil
        showBlockedOverlay = false
        lastBlockedURL = nil
        lastBlockReason = nil
    }

    // MARK: - Computed Helpers

    var isResolving: Bool {
        if case .resolving = state { return true }
        return false
    }

    var canonicalURL: URL? {
        if case .locked(let url) = state { return url }
        return nil
    }
}
