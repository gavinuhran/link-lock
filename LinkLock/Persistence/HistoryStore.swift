import Foundation
import Combine

/// Persists session history to UserDefaults as a Codable array.
/// Suitable for MVP — upgrade to CoreData/SQLite if list grows large.
final class HistoryStore: ObservableObject {

    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let key = "linklock.history.v1"

    private init() {
        load()
    }

    // MARK: - Public API

    func add(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0) // newest first
        save()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }
}
