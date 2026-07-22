import Foundation
import Observation

/// Owns the live match and keeps it on disk so closing the app mid-match
/// doesn't lose the score.
@Observable
@MainActor
final class MatchStore {
    private(set) var match: MatchState?

    /// Remembered between matches so the setup screen can prefill.
    private(set) var lastConfig: MatchConfig

    private let defaults: UserDefaults
    private static let matchKey = "fast4.currentMatch"
    private static let configKey = "fast4.lastConfig"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastConfig = Self.load(MatchConfig.self, key: Self.configKey, from: defaults) ?? MatchConfig()
        self.match = Self.load(MatchSnapshot.self, key: Self.matchKey, from: defaults)?.state
    }

    // MARK: - Actions

    func start(_ config: MatchConfig) {
        lastConfig = config
        match = MatchState(config: config)
        save()
    }

    func award(to player: Player) {
        guard var current = match, !current.isOver else { return }
        current.award(to: player)
        match = current
        save()
    }

    func undo() {
        guard var current = match, current.canUndo else { return }
        current.undo()
        match = current
        save()
    }

    /// Discards the match and returns to setup.
    func end() {
        match = nil
        defaults.removeObject(forKey: Self.matchKey)
    }

    /// Same players, same format, fresh score.
    func rematch() {
        guard let config = match?.config else { return }
        start(config)
    }

    // MARK: - Persistence

    private func save() {
        if let match {
            store(MatchSnapshot(match), key: Self.matchKey)
        }
        store(lastConfig, key: Self.configKey)
    }

    private func store<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
