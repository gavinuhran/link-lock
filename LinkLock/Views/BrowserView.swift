import SwiftUI

/// Full-screen locked browser. Hosts WebView + blocked-navigation overlay.
/// The user cannot see an address bar or navigate away from the initial URL.
struct BrowserView: View {

    let url: URL
    let allowsNavigation: Bool
    var onBlockTerminated: () -> Void = {}
    @StateObject private var session = SessionManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack {
                    // Done button (matches SFSafariViewController style)
                    Button("Done") {
                        session.endSession()
                        dismiss()
                    }
                    .fontWeight(.semibold)

                    Spacer()

                    // Mode icon + domain
                    HStack(spacing: 4) {
                        Image(systemName: allowsNavigation ? "qrcode" : "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(displayDomain)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Invisible spacer to balance "Done" width
                    Text("Done")
                        .fontWeight(.semibold)
                        .hidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)

                Divider()

                // MARK: - Web View
                WebView(url: url, session: session)
                    .ignoresSafeArea(edges: .bottom)
            }

            // Loading indicator during redirect resolution phase.
            if session.isResolving {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.4)
                    Text("Loading…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

        }
        .navigationBarHidden(true)
        .onAppear {
            session.startSession(url: url, allowsNavigation: allowsNavigation)
        }
        .onDisappear {
            if session.currentSession != nil {
                session.endSession()
            }
        }
        .onChange(of: session.wasTerminated) { terminated in
            if terminated {
                onBlockTerminated()
                dismiss()
            }
        }
    }

    /// Shows the canonical domain once locked, otherwise the original URL's host.
    private var displayDomain: String {
        let domainURL = session.canonicalURL ?? url
        return domainURL.host ?? domainURL.absoluteString
    }
}
