import Foundation

/// The Fast4 rule constants. Collected here so the numbers that define the
/// format are stated once, in one place.
enum Fast4Rules {
    /// No-ad games: first to four points takes the game (40-40 is a deciding point).
    static let pointsToWinGame = 4
    /// A set is won at four games...
    static let gamesToWinSet = 4
    /// ...unless the set reaches this many games all, which forces a set tie-break.
    static let tiebreakAtGames = 3
    /// Set tie-break: first to five, deciding point at 4-4.
    static let setTiebreakPoints = 5
    /// Match tie-break: first to ten, deciding point at 9-9.
    static let matchTiebreakPoints = 10
}

/// Everything chosen before the first ball is struck.
struct MatchConfig: Codable, Equatable, Hashable {
    var playerOneName: String = "Player 1"
    var playerTwoName: String = "Player 2"

    /// Sets needed to win the match: 2 for best-of-3, 3 for best-of-5.
    var setsToWin: Int = 2

    /// When true, a deciding set (1-1 in a best-of-3, 2-2 in a best-of-5) is
    /// played as a 10-point match tie-break instead of a normal set.
    var finalSetIsMatchTiebreak: Bool = true

    var firstServer: Player = .one

    var bestOf: Int { setsToWin * 2 - 1 }

    func name(_ player: Player) -> String {
        player == .one ? playerOneName : playerTwoName
    }

    /// Names guaranteed to be non-empty, for display.
    func displayName(_ player: Player) -> String {
        let raw = name(player).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? (player == .one ? "Player 1" : "Player 2") : raw
    }
}
