import WebKit

/// Pure, stateless decision engine for WKWebView navigation policy.
/// No side effects — all inputs explicit, all outputs deterministic.
/// Designed for unit-testability without a running WKWebView.
struct NavigationPolicyEngine {

    // MARK: - Main Decision

    /// Evaluate a navigation action against the current session state.
    static func decide(
        navigationAction action: WKNavigationAction,
        sessionState: SessionState
    ) -> PolicyDecision {
        guard let url = action.request.url else {
            return .block(.nilURL)
        }
        return decide(url: url,
                      isMainFrame: action.targetFrame?.isMainFrame ?? true,
                      sessionState: sessionState)
    }

    /// Overload accepting raw values — usable from unit tests without WKNavigationAction.
    static func decide(
        url: URL,
        isMainFrame: Bool,
        sessionState: SessionState
    ) -> PolicyDecision {

        // Rule 1: Non-http(s) scheme — always block regardless of frame or state.
        // Covers: mailto:, tel:, youtube://, fb://, itms-apps://, sms:, facetime:, etc.
        guard url.isHTTPOrHTTPS else {
            return .block(.nonHttpScheme)
        }

        // Rule 2: Subframe (iframe) navigation — allow all http(s).
        // Subresource loads (images, CSS, JS) do not pass through this delegate.
        // Iframe navigations do, but they're embedded content — allow them.
        guard isMainFrame else {
            return .allow
        }

        // Rule 3: Resolving phase — allow all main-frame http(s) navigations
        // so redirect chains can complete before we lock the canonical URL.
        if case .resolving = sessionState {
            return .allow
        }

        // Rule 4: Locked phase — only the canonical URL (with any fragment) is allowed.
        if case .locked(let canonical) = sessionState {
            // Fragment-only change: allow (same resource, different anchor).
            if url.sameResource(as: canonical) {
                return .allow
            }
            // Any other main-frame navigation: block.
            return .block(.mainFrameNavigation)
        }

        // Rule 5: .idle or .ended — shouldn't reach browser, but be safe.
        return .allow
    }

    // MARK: - Response Policy

    /// Evaluate whether a committed navigation response should be allowed.
    /// Used to catch Content-Disposition: attachment download attempts.
    static func decideResponse(mimeType: String?, contentDisposition: String?) -> PolicyDecision {
        // Block explicit download responses.
        if let disposition = contentDisposition,
           disposition.lowercased().hasPrefix("attachment") {
            return .block(.downloadBlocked)
        }
        return .allow
    }
}
