import Foundation

// MARK: - Block Reason

enum BlockReason: String, Codable {
    case nonHttpScheme      // mailto:, tel:, youtube://, etc.
    case mainFrameNavigation // navigation away from canonical URL
    case newWindowRequest    // target="_blank" or window.open()
    case postLockRedirect    // server redirect after canonical is locked
    case spaNavigation       // pushState/replaceState path change
    case nilURL              // nil URL in navigation action
    case downloadBlocked     // Content-Disposition: attachment
}

// MARK: - Policy Decision

enum PolicyDecision {
    case allow
    case block(BlockReason)
}
