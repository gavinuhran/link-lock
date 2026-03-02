import SwiftUI

@main
struct LinkLockApp: App {

    /// Populated by the Share Extension via linklock://open?url=... deep link.
    @State private var pendingURL: URL?

    var body: some Scene {
        WindowGroup {
            HomeView(pendingURL: $pendingURL)
                .onOpenURL { incomingURL in
                    pendingURL = resolve(deepLink: incomingURL)
                }
        }
    }

    // MARK: - Deep Link Parsing

    /// Parses linklock://open?url=<percent-encoded-url> from the Share Extension.
    /// Returns nil for malformed or non-http(s) URLs.
    private func resolve(deepLink url: URL) -> URL? {
        guard url.scheme == "linklock",
              url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encodedURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let target = URL(string: encodedURL),
              target.isHTTPOrHTTPS
        else { return nil }
        return target
    }
}
