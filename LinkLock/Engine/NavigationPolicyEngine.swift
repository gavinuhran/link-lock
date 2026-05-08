import WebKit

/// Pure, stateless decision engine for WKWebView navigation policy.
/// No side effects — all inputs explicit, all outputs deterministic.
/// Designed for unit-testability without a running WKWebView.
struct NavigationPolicyEngine {

    // MARK: - Main Decision

    static func decide(
        navigationAction action: WKNavigationAction,
        sessionState: SessionState,
        allowsNavigation: Bool = false
    ) -> PolicyDecision {
        guard let url = action.request.url else {
            return .block(.nilURL)
        }
        return decide(url: url,
                      isMainFrame: action.targetFrame?.isMainFrame ?? true,
                      sessionState: sessionState,
                      allowsNavigation: allowsNavigation)
    }

    /// Overload accepting raw values — usable from unit tests without WKNavigationAction.
    static func decide(
        url: URL,
        isMainFrame: Bool,
        sessionState: SessionState,
        allowsNavigation: Bool = false
    ) -> PolicyDecision {

        // Rule 1: Non-http(s) scheme — block external app schemes.
        // Allow about: (about:blank, about:srcdoc) — used internally by pages for iframes.
        // Covers: mailto:, tel:, youtube://, fb://, itms-apps://, sms:, facetime:, etc.
        guard url.isHTTPOrHTTPS || url.schemeLowercased == "about" else {
            return .block(.nonHttpScheme)
        }

        // Rule 2: Subframe (iframe) navigation — allow all http(s).
        guard isMainFrame else {
            return .allow
        }

        // Rule 3: Resolving phase — allow all main-frame http(s) navigations
        // so redirect chains can complete before we lock the canonical URL.
        if case .resolving = sessionState {
            return .allow
        }

        // Rule 4: Locked phase.
        if case .locked(let canonical) = sessionState {
            // QR sessions allow any http(s) main-frame navigation.
            if allowsNavigation { return .allow }
            // Default: only the canonical URL (with any fragment) is allowed.
            if url.sameResource(as: canonical) { return .allow }
            return .block(.mainFrameNavigation)
        }

        // Rule 5: .idle or .ended — shouldn't reach browser, but be safe.
        return .allow
    }

    // MARK: - Response Policy

    /// Evaluate whether a committed navigation response should be allowed.
    /// Used to catch Content-Disposition: attachment download attempts.
    static func decideResponse(mimeType: String?, contentDisposition: String?) -> PolicyDecision {
        if let disposition = contentDisposition,
           disposition.lowercased().hasPrefix("attachment") {
            return .block(.downloadBlocked)
        }
        return .allow
    }
}
