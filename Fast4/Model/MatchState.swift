import Foundation

/// What is being played right now.
enum Phase: Equatable {
    case game
    case setTiebreak
    case matchTiebreak
    case matchOver
}

/// A set that has finished.
struct CompletedSet: Equatable, Identifiable {
    var index: Int
    var games: [Int]
    /// Points in the tie-break that decided the set, if one did.
    var tiebreakPoints: [Int]?
    var wasMatchTiebreak: Bool
    var winner: Player

    var id: Int { index }

    /// e.g. "4-2", "4-3" (set tie-break), "10-8" (match tie-break)
    func score(from perspective: Player) -> String {
        let mine = perspective.rawValue
        let theirs = perspective.opponent.rawValue
        if wasMatchTiebreak, let tb = tiebreakPoints {
            return "\(tb[mine])-\(tb[theirs])"
        }
        return "\(games[mine])-\(games[theirs])"
    }
}

/// One point, recorded for the history log.
struct MatchEvent: Identifiable, Equatable {
    /// Zero-based index into the point log.
    var id: Int
    var setNumber: Int
    var gameNumber: Int
    var winner: Player
    var server: Player
    var wasDecidingPoint: Bool
    /// Score after the point, from player one's perspective ("30-15", "3-2").
    var scoreAfter: String
    /// "Game", "Set 4-2", "Match" — set when the point closed something out.
    var milestone: String?
    var isTiebreakPoint: Bool
}

/// The complete state of a Fast4 match.
///
/// Only `config` and `pointLog` are authoritative; everything else is derived
/// by replaying the log from the start. Undo is therefore just dropping the
/// last point and replaying, which can never leave the state inconsistent.
struct MatchState: Equatable {
    let config: MatchConfig
    private(set) var pointLog: [Player] = []

    // MARK: Derived state
    private(set) var completedSets: [CompletedSet] = []
    private(set) var setsWon: [Int] = [0, 0]
    /// Games in the current set.
    private(set) var games: [Int] = [0, 0]
    /// Points in the current game or tie-break.
    private(set) var points: [Int] = [0, 0]
    private(set) var phase: Phase = .game
    private(set) var server: Player = .one
    private(set) var winner: Player?
    private(set) var events: [MatchEvent] = []

    /// Who served the first point of the tie-break in progress.
    private var tiebreakFirstServer: Player?

    init(config: MatchConfig, pointLog: [Player] = []) {
        self.config = config
        self.pointLog = pointLog
        replay()
    }

    // MARK: - Mutation

    mutating func award(to player: Player) {
        guard phase != .matchOver else { return }
        pointLog.append(player)
        replay()
    }

    mutating func undo() {
        guard !pointLog.isEmpty else { return }
        pointLog.removeLast()
        replay()
    }

    var canUndo: Bool { !pointLog.isEmpty }
    var isOver: Bool { phase == .matchOver }

    // MARK: - Replay

    private mutating func replay() {
        completedSets = []
        setsWon = [0, 0]
        games = [0, 0]
        points = [0, 0]
        events = []
        winner = nil
        server = config.firstServer
        tiebreakFirstServer = nil
        phase = phaseForNewSet()
        if phase == .matchTiebreak { tiebreakFirstServer = server }

        for (index, pointWinner) in pointLog.enumerated() {
            guard phase != .matchOver else { break }
            apply(pointWinner, index: index)
        }
    }

    /// A deciding set is played as a match tie-break when both players are one
    /// set from victory and the option is enabled.
    private func phaseForNewSet() -> Phase {
        let onePointFromMatch = config.setsToWin - 1
        if config.finalSetIsMatchTiebreak,
           setsWon[.one] == onePointFromMatch,
           setsWon[.two] == onePointFromMatch {
            return .matchTiebreak
        }
        return .game
    }

    private mutating func apply(_ pointWinner: Player, index: Int) {
        let serverForPoint = server
        let deciding = isDecidingPoint
        let inTiebreak = phase != .game
        let setNumber = completedSets.count + 1
        let gameNumber = games[.one] + games[.two] + 1

        points[pointWinner] += 1
        var milestone: String?

        switch phase {
        case .game:
            if points[pointWinner] >= Fast4Rules.pointsToWinGame {
                games[pointWinner] += 1
                points = [0, 0]
                server = server.opponent
                milestone = "Game"

                if games[pointWinner] >= Fast4Rules.gamesToWinSet {
                    milestone = finishSet(wonBy: pointWinner, tiebreakPoints: nil, matchTiebreak: false)
                } else if games[.one] == Fast4Rules.tiebreakAtGames,
                          games[.two] == Fast4Rules.tiebreakAtGames {
                    phase = .setTiebreak
                    tiebreakFirstServer = server
                    milestone = "Game — set tie-break"
                }
            }

        case .setTiebreak:
            if points[pointWinner] >= Fast4Rules.setTiebreakPoints {
                let tb = points
                games[pointWinner] += 1  // tie-break winner takes the set 4-3
                milestone = finishSet(wonBy: pointWinner, tiebreakPoints: tb, matchTiebreak: false)
            } else {
                updateTiebreakServer()
            }

        case .matchTiebreak:
            if points[pointWinner] >= Fast4Rules.matchTiebreakPoints {
                let tb = points
                games[pointWinner] += 1
                milestone = finishSet(wonBy: pointWinner, tiebreakPoints: tb, matchTiebreak: true)
            } else {
                updateTiebreakServer()
            }

        case .matchOver:
            return
        }

        events.append(
            MatchEvent(
                id: index,
                setNumber: setNumber,
                gameNumber: gameNumber,
                winner: pointWinner,
                server: serverForPoint,
                wasDecidingPoint: deciding,
                scoreAfter: milestone == nil ? scoreLine(inTiebreak: inTiebreak) : "—",
                milestone: milestone,
                isTiebreakPoint: inTiebreak
            )
        )
    }

    /// Closes out the current set and starts the next one (or ends the match).
    /// Returns the milestone string for the history log.
    private mutating func finishSet(
        wonBy player: Player,
        tiebreakPoints: [Int]?,
        matchTiebreak: Bool
    ) -> String {
        let set = CompletedSet(
            index: completedSets.count,
            games: games,
            tiebreakPoints: tiebreakPoints,
            wasMatchTiebreak: matchTiebreak,
            winner: player
        )
        completedSets.append(set)
        setsWon[player] += 1

        // After a tie-break, the player who served first in it receives first
        // in the next set.
        if let first = tiebreakFirstServer, tiebreakPoints != nil {
            server = first.opponent
        }

        games = [0, 0]
        points = [0, 0]
        tiebreakFirstServer = nil

        if setsWon[player] >= config.setsToWin {
            phase = .matchOver
            winner = player
            return "Match — \(set.score(from: player))"
        }

        phase = phaseForNewSet()
        if phase == .matchTiebreak { tiebreakFirstServer = server }
        return "Set — \(set.score(from: player))"
    }

    /// Tie-break serving: one point, then alternating every two points.
    private mutating func updateTiebreakServer() {
        guard let first = tiebreakFirstServer else { return }
        let played = points[.one] + points[.two]
        // Points 0 | 1,2 | 3,4 | 5,6 ... belong to alternating servers.
        server = ((played + 1) / 2) % 2 == 0 ? first : first.opponent
    }

    // MARK: - Display helpers

    /// True when the very next point decides the game, tie-break, or match.
    var isDecidingPoint: Bool {
        switch phase {
        case .game:
            return points[.one] == Fast4Rules.pointsToWinGame - 1
                && points[.two] == Fast4Rules.pointsToWinGame - 1
        case .setTiebreak:
            return points[.one] == Fast4Rules.setTiebreakPoints - 1
                && points[.two] == Fast4Rules.setTiebreakPoints - 1
        case .matchTiebreak:
            return points[.one] == Fast4Rules.matchTiebreakPoints - 1
                && points[.two] == Fast4Rules.matchTiebreakPoints - 1
        case .matchOver:
            return false
        }
    }

    private static let gamePointNames = ["0", "15", "30", "40"]

    /// The point score to show for a player: "0/15/30/40" in a game, raw count
    /// in a tie-break.
    func pointDisplay(for player: Player) -> String {
        switch phase {
        case .game:
            let value = min(points[player], Self.gamePointNames.count - 1)
            return Self.gamePointNames[value]
        case .setTiebreak, .matchTiebreak:
            return String(points[player])
        case .matchOver:
            return "—"
        }
    }

    private func scoreLine(inTiebreak: Bool) -> String {
        if inTiebreak {
            return "\(points[.one])-\(points[.two])"
        }
        return "\(pointDisplay(for: .one))-\(pointDisplay(for: .two))"
    }

    /// A one-line description of what's being contested, e.g.
    /// "Set 2 · Game 5" or "Match tie-break".
    var situationDescription: String {
        switch phase {
        case .matchOver:
            guard let winner else { return "Match complete" }
            return "\(config.displayName(winner)) wins"
        case .matchTiebreak:
            return "Match tie-break — first to \(Fast4Rules.matchTiebreakPoints)"
        case .setTiebreak:
            return "Set \(completedSets.count + 1) · tie-break — first to \(Fast4Rules.setTiebreakPoints)"
        case .game:
            return "Set \(completedSets.count + 1) · Game \(games[.one] + games[.two] + 1)"
        }
    }

    /// Final score read out from the winner's side, e.g. "4-2, 3-4, 10-7".
    var finalScoreDescription: String {
        guard let winner else { return "" }
        return completedSets.map { $0.score(from: winner) }.joined(separator: ", ")
    }
}

// MARK: - Persistence

/// The minimal snapshot that can rebuild a match exactly.
struct MatchSnapshot: Codable {
    var config: MatchConfig
    var pointLog: [Player]

    init(_ state: MatchState) {
        self.config = state.config
        self.pointLog = state.pointLog
    }

    var state: MatchState { MatchState(config: config, pointLog: pointLog) }
}
