import SwiftUI

/// Full-screen locked browser. Hosts WebView + blocked-navigation overlay.
/// The user cannot see an address bar or navigate away from the initial URL.
struct BrowserView: View {

    let url: URL
    @StateObject private var session = SessionManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Full-bleed web view — extends into safe areas for immersive feel.
            WebView(url: url, session: session)
                .ignoresSafeArea()

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

            // Blocked navigation overlay.
            if session.showBlockedOverlay {
                BlockedNavigationOverlay(
                    blockedURL: session.lastBlockedURL,
                    reason: session.lastBlockReason,
                    onStay: { session.dismissOverlay() },
                    onEnd: {
                        session.endSession()
                        dismiss()
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
        }
        // Hide navigation chrome — no URL bar, no back button.
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .onAppear {
            session.startSession(url: url)
        }
        .onDisappear {
            // Handles hardware back-swipe or programmatic dismiss.
            if session.currentSession != nil {
                session.endSession()
            }
        }
    }
}
