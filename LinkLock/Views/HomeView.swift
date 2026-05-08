import SwiftUI
import VisionKit

/// Entry point. Lets the user paste a URL and open a locked session.
/// Also handles deep links from the Share Extension (linklock://open?url=...).
struct HomeView: View {

    @State private var urlText = ""
    @State private var navigateToBrowser = false
    @State private var targetURL: URL?
    @State private var allowsNavigation = false
    @State private var showQRScanner = false
    @State private var showBlockedBanner = false

    // Passed from LinkLockApp when opened via Share Extension deep link.
    @Binding var pendingURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Blocked banner
                if showBlockedBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                        Text("Site blocked — session ended.")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // MARK: Logo / Title
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    Text("Link Lock")
                        .font(.largeTitle.bold())
                    Text("Open one link. Go nowhere else.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer().frame(height: 48)

                // MARK: URL Entry
                VStack(spacing: 12) {
                    TextField("Paste a link…", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onSubmit { tryOpen() }

                    HStack(spacing: 12) {
                        Button(action: tryOpen) {
                            Label("Open", systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!isValidURL)

                        Button { showQRScanner = true } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title3)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                // MARK: History link
                NavigationLink("View History") {
                    HistoryView()
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            }
            .navigationDestination(isPresented: $navigateToBrowser) {
                if let url = targetURL {
                    BrowserView(url: url, allowsNavigation: allowsNavigation, onBlockTerminated: {
                        withAnimation { showBlockedBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showBlockedBanner = false }
                        }
                    })
                }
            }
        }
        // Handle deep links from Share Extension.
        .onChange(of: pendingURL) { newURL in
            guard let url = newURL else { return }
            urlText = url.absoluteString
            allowsNavigation = false
            targetURL = url
            navigateToBrowser = true
            pendingURL = nil
        }
        .sheet(isPresented: $showQRScanner) {
            if DataScannerViewController.isSupported {
                QRScannerView { url in
                    showQRScanner = false
                    urlText = url.absoluteString
                    allowsNavigation = true
                    targetURL = url
                    navigateToBrowser = true
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("QR Scanning Unavailable")
                        .font(.headline)
                    Text("QR code scanning requires a physical device with a camera.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") { showQRScanner = false }
                        .buttonStyle(.bordered)
                }
                .padding(32)
            }
        }
    }

    // MARK: - Helpers

    private var isValidURL: Bool {
        normalizedURL != nil
    }

    private var normalizedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Prepend https:// if no scheme given.
        let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), url.isHTTPOrHTTPS else { return nil }
        return url
    }

    private func tryOpen() {
        guard let url = normalizedURL else { return }
        allowsNavigation = false
        targetURL = url
        navigateToBrowser = true
    }
}

// MARK: - History View (minimal)

struct HistoryView: View {

    @ObservedObject private var store = HistoryStore.shared

    var body: some View {
        List {
            if store.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No sessions yet")
                        .font(.headline)
                    Text("Your session history will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.entries) { entry in
                    HistoryRowView(entry: entry)
                }
            }
        }
        .navigationTitle("History")
    }
}

struct HistoryRowView: View {

    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.canonicalURL.host ?? entry.canonicalURL.absoluteString)
                .font(.headline)
                .lineLimit(1)
            Text(entry.canonicalURL.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack {
                Label(entry.formattedDuration, systemImage: "clock")
                Spacer()
                if entry.blockedAttempts > 0 {
                    Label("\(entry.blockedAttempts) blocked", systemImage: "lock.fill")
                        .foregroundColor(.orange)
                }
                Text(entry.startTime, style: .date)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView(pendingURL: .constant(nil))
}
