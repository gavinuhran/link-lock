import SwiftUI

/// Entry point. Lets the user paste a URL and open a locked session.
/// Also handles deep links from the Share Extension (linklock://open?url=...).
struct HomeView: View {

    @State private var urlText = ""
    @State private var navigateToBrowser = false
    @State private var targetURL: URL?

    // Passed from LinkLockApp when opened via Share Extension deep link.
    @Binding var pendingURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                    Button(action: tryOpen) {
                        Label("Open", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isValidURL)
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
                    BrowserView(url: url)
                }
            }
        }
        // Handle deep links from Share Extension.
        .onChange(of: pendingURL) { _, newURL in
            guard let url = newURL else { return }
            urlText = url.absoluteString
            targetURL = url
            navigateToBrowser = true
            pendingURL = nil
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
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock",
                    description: Text("Your session history will appear here.")
                )
            } else {
                ForEach(store.entries) { entry in
                    HistoryRowView(entry: entry)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !store.entries.isEmpty {
                Button("Clear", role: .destructive) {
                    store.clear()
                }
            }
        }
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
