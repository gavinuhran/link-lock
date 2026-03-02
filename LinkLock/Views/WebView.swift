import SwiftUI
import WebKit

// MARK: - WebView (UIViewRepresentable)

/// Wraps WKWebView for SwiftUI. The Coordinator handles all delegate callbacks
/// and is the single point of contact between WebKit and SessionManager.
struct WebView: UIViewRepresentable {

    let url: URL
    @ObservedObject var session: SessionManager

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Register the SPA interception message handler.
        config.userContentController.add(context.coordinator, name: "spaBlocked")

        // Defense-in-depth: prevent JS from auto-opening windows.
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Allow inline media playback (needed for video pages like YouTube).
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Disable long-press link preview — prevents "Open in Safari" context menu.
        webView.allowsLinkPreview = false

        // Store a reference so the coordinator can call evaluateJavaScript.
        context.coordinator.webView = webView

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No dynamic updates needed — URL is set once at makeUIView time.
    }
}

// MARK: - Coordinator

extension WebView {

    final class Coordinator: NSObject {

        weak var webView: WKWebView?
        private let session: SessionManager

        init(session: SessionManager) {
            self.session = session
        }

        // MARK: - SPA Injection

        /// Injects a JS snippet that intercepts history.pushState / replaceState
        /// and swallows calls that would navigate away from the canonical path+query.
        func injectSPAInterceptor(canonical: URL) {
            let path = canonical.path.isEmpty ? "/" : canonical.path
            // Escape single quotes to avoid JS injection from URL content.
            let safePath = path.replacingOccurrences(of: "'", with: "\\'")
            let safeQuery = (canonical.query ?? "").replacingOccurrences(of: "'", with: "\\'")

            let js = """
            (function(cp, cq) {
                if (window.__ll_spa_patched) return;
                window.__ll_spa_patched = true;
                function sameResource(u) {
                    try {
                        const n = new URL(u, location.href);
                        const expectedSearch = cq ? ('?' + cq) : '';
                        return n.pathname === cp && n.search === expectedSearch;
                    } catch(e) { return true; }
                }
                const _push    = history.pushState.bind(history);
                const _replace = history.replaceState.bind(history);
                history.pushState = function(s, t, u) {
                    if (u != null && !sameResource(String(u))) {
                        window.webkit.messageHandlers.spaBlocked.postMessage({url: String(u), type: 'pushState'});
                        return; // swallow — do not call original
                    }
                    return _push(s, t, u);
                };
                history.replaceState = function(s, t, u) {
                    if (u != null && !sameResource(String(u))) {
                        window.webkit.messageHandlers.spaBlocked.postMessage({url: String(u), type: 'replaceState'});
                        return;
                    }
                    return _replace(s, t, u);
                };
            })('\(safePath)', '\(safeQuery)');
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebView.Coordinator: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let decision = NavigationPolicyEngine.decide(
            navigationAction: action,
            sessionState: session.state
        )
        switch decision {
        case .allow:
            decisionHandler(.allow)
        case .block(let reason):
            decisionHandler(.cancel)
            Task { @MainActor in
                self.session.recordBlocked(reason: reason, url: action.request.url)
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor response: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let httpResponse = response.response as? HTTPURLResponse
        let contentDisposition = httpResponse?.value(forHTTPHeaderField: "Content-Disposition")
        let mimeType = response.response.mimeType

        let decision = NavigationPolicyEngine.decideResponse(
            mimeType: mimeType,
            contentDisposition: contentDisposition
        )
        switch decision {
        case .allow:
            decisionHandler(.allow)
        case .block(let reason):
            decisionHandler(.cancel)
            Task { @MainActor in
                self.session.recordBlocked(reason: reason, url: response.response.url)
            }
        }
    }

    func webView(_ webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
        // First commit = final URL after all server-side redirects. Lock it.
        if session.isResolving, let url = webView.url {
            Task { @MainActor in
                self.session.lockCanonical(url: url)
            }
            injectSPAInterceptor(canonical: url)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Navigation errors don't require special handling — the page just won't load.
        // Log for diagnostics.
        EventLogger.shared.log(
            .sessionEnd,
            sessionID: session.currentSession?.id,
            url: webView.url,
            details: "didFail: \(error.localizedDescription)"
        )
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        EventLogger.shared.log(
            .sessionEnd,
            sessionID: session.currentSession?.id,
            url: webView.url,
            details: "didFailProvisional: \(error.localizedDescription)"
        )
    }
}

// MARK: - WKUIDelegate

extension WebView.Coordinator: WKUIDelegate {

    /// Returning nil blocks all target="_blank" links and window.open() calls.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        Task { @MainActor in
            self.session.recordBlocked(reason: .newWindowRequest, url: navigationAction.request.url)
        }
        return nil
    }
}

// MARK: - WKScriptMessageHandler (SPA intercept)

extension WebView.Coordinator: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "spaBlocked",
              let body = message.body as? [String: String] else { return }
        let urlString = body["url"]
        let blockedURL = urlString.flatMap { URL(string: $0) }
        Task { @MainActor in
            self.session.recordBlocked(reason: .spaNavigation, url: blockedURL)
        }
    }
}
