import SwiftUI

struct BlockedNavigationOverlay: View {

    let blockedURL: URL?
    let reason: BlockReason?
    let onStay: () -> Void
    let onEnd: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onStay() } // Tap outside = Stay

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.primary)

                Text("This would leave your link.")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let url = blockedURL {
                    Text(url.host ?? url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let r = reason {
                    Text(reasonDescription(r))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button(action: onStay) {
                        Text("Stay")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onEnd) {
                        Text("End Session")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                // Deliberately no "Open in Safari" option.
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
        }
    }

    private func reasonDescription(_ reason: BlockReason) -> String {
        switch reason {
        case .nonHttpScheme:      return "External app link blocked."
        case .mainFrameNavigation: return "Navigation to a different page blocked."
        case .newWindowRequest:   return "New window or tab blocked."
        case .postLockRedirect:   return "Server redirect after lock blocked."
        case .spaNavigation:      return "In-app route change blocked."
        case .nilURL:             return "Unknown URL blocked."
        case .downloadBlocked:    return "File download blocked."
        }
    }
}

#Preview {
    BlockedNavigationOverlay(
        blockedURL: URL(string: "https://youtube.com/watch?v=other"),
        reason: .mainFrameNavigation,
        onStay: {},
        onEnd: {}
    )
}
