import Foundation

// A dependency-free test harness for the scoring engine. Compile with:
//   swiftc -O Fast4/Model/*.swift EngineTests/main.swift -o /tmp/enginetests && /tmp/enginetests

var failures = 0
var checks = 0

func check(_ condition: Bool, _ label: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("  FAIL [\(line)] \(label)")
    }
}

func equal<T: Equatable>(_ actual: T, _ expected: T, _ label: String, line: UInt = #line) {
    checks += 1
    if actual != expected {
        failures += 1
        print("  FAIL [\(line)] \(label): got \(actual), expected \(expected)")
    }
}

func section(_ name: String) { print("\n\(name)") }

/// Feed a string of "A"/"B" point winners into a match.
extension MatchState {
    mutating func play(_ sequence: String) {
        for character in sequence {
            switch character {
            case "A": award(to: .one)
            case "B": award(to: .two)
            case " ", "|", "-": continue
            default: fatalError("bad point character \(character)")
            }
        }
    }
}

func newMatch(
    setsToWin: Int = 2,
    matchTB: Bool = true,
    firstServer: Player = .one
) -> MatchState {
    var config = MatchConfig()
    config.playerOneName = "A"
    config.playerTwoName = "B"
    config.setsToWin = setsToWin
    config.finalSetIsMatchTiebreak = matchTB
    config.firstServer = firstServer
    return MatchState(config: config)
}

/// Repeat a whole game won by one player, `count` times, alternating as given.
func games(_ pattern: String) -> String {
    pattern.map { String(repeating: String($0), count: 4) }.joined()
}

// MARK: - No-ad games

section("No-ad game scoring")
do {
    var m = newMatch()
    m.play("AAA")
    equal(m.pointDisplay(for: .one), "40", "three points shows 40")
    equal(m.pointDisplay(for: .two), "0", "opponent still 0")
    check(!m.isDecidingPoint, "40-0 is not a deciding point")
    m.play("A")
    equal(m.games[.one], 1, "fourth point wins the game")
    equal(m.points, [0, 0], "points reset after a game")
}

do {
    var m = newMatch()
    m.play("AAABBB")
    equal(m.pointDisplay(for: .one), "40", "40-40 reached")
    equal(m.pointDisplay(for: .two), "40", "40-40 reached")
    check(m.isDecidingPoint, "40-40 is the deciding point (sudden death)")
    m.play("B")
    equal(m.games[.two], 1, "deciding point wins the game outright — no advantage")
    equal(m.games[.one], 0, "loser of the deciding point gets nothing")
}

// MARK: - Set scoring

section("Set: first to 4 games")
do {
    var m = newMatch()
    m.play(games("AAAA"))
    equal(m.completedSets.count, 1, "4-0 completes the set")
    equal(m.setsWon[.one], 1, "set credited")
    equal(m.completedSets[0].games, [4, 0], "set score 4-0")
    check(m.completedSets[0].tiebreakPoints == nil, "no tie-break in a 4-0 set")
}

do {
    var m = newMatch()
    m.play(games("ABABAA"))  // 4-2
    equal(m.completedSets.count, 1, "4-2 completes the set")
    equal(m.completedSets[0].games, [4, 2], "set score 4-2")
}

section("Set tie-break at 3-3")
do {
    var m = newMatch()
    m.play(games("ABABAB"))  // 3-3
    equal(m.games, [3, 3], "games level at 3-3")
    equal(m.phase, .setTiebreak, "3-3 forces the set tie-break")
    equal(m.pointDisplay(for: .one), "0", "tie-break shows raw points")

    m.play("AAAA")
    equal(m.points, [4, 0], "tie-break at 4-0")
    check(m.completedSets.isEmpty, "four points does not win a set tie-break")
    m.play("A")
    equal(m.completedSets.count, 1, "fifth point wins the set tie-break")
    equal(m.completedSets[0].games, [4, 3], "tie-break winner takes the set 4-3")
    equal(m.completedSets[0].tiebreakPoints ?? [], [5, 0], "tie-break points recorded")
}

do {
    var m = newMatch()
    m.play(games("ABABAB"))
    m.play("AAAABBBB")
    equal(m.points, [4, 4], "tie-break at 4-4")
    check(m.isDecidingPoint, "4-4 in a set tie-break is a deciding point")
    m.play("B")
    equal(m.completedSets.count, 1, "deciding point ends the tie-break")
    equal(m.completedSets[0].winner, .two, "B takes it")
    equal(m.completedSets[0].games, [3, 4], "set score 3-4")
}

// MARK: - Match tie-break

section("Deciding set as a match tie-break (best of 3)")
do {
    var m = newMatch(setsToWin: 2, matchTB: true)
    m.play(games("AAAA"))       // A wins set 1
    m.play(games("BBBB"))       // B wins set 2
    equal(m.setsWon, [1, 1], "one set all")
    equal(m.phase, .matchTiebreak, "1-1 starts the match tie-break")

    m.play(String(repeating: "A", count: 9))
    m.play(String(repeating: "B", count: 9))
    equal(m.points, [9, 9], "match tie-break at 9-9")
    check(m.isDecidingPoint, "9-9 is the deciding point")
    check(!m.isOver, "nobody has won yet at 9-9")
    m.play("A")
    check(m.isOver, "tenth point wins the match tie-break")
    equal(m.winner, .one, "A wins the match")
    equal(m.completedSets.last?.tiebreakPoints ?? [], [10, 9], "match tie-break score recorded")
    check(m.completedSets.last?.wasMatchTiebreak == true, "flagged as a match tie-break")
}

do {
    var m = newMatch(setsToWin: 2, matchTB: false)
    m.play(games("AAAA"))
    m.play(games("BBBB"))
    equal(m.phase, .game, "with the option off, the deciding set is a normal set")
    m.play(games("AAAA"))
    check(m.isOver, "normal deciding set finishes the match")
    equal(m.completedSets.count, 3, "three sets played")
}

section("Best of 5 — match tie-break only at 2-2")
do {
    var m = newMatch(setsToWin: 3, matchTB: true)
    m.play(games("AAAA"))
    m.play(games("BBBB"))
    equal(m.phase, .game, "1-1 in a best-of-5 is still a normal set")
    m.play(games("AAAA"))
    m.play(games("BBBB"))
    equal(m.setsWon, [2, 2], "two sets all")
    equal(m.phase, .matchTiebreak, "2-2 in a best-of-5 starts the match tie-break")
    m.play(String(repeating: "B", count: 10))
    check(m.isOver, "B wins the best-of-5")
    equal(m.winner, .two, "winner is B")
}

// MARK: - Match completion

section("Match ends and ignores further points")
do {
    var m = newMatch(setsToWin: 2, matchTB: false)
    m.play(games("AAAA"))
    m.play(games("AAAA"))
    check(m.isOver, "two sets wins a best-of-3")
    equal(m.setsWon[.one], 2, "2-0 in sets")
    let before = m
    m.award(to: .two)
    equal(m, before, "points after match point are ignored")
}

// MARK: - Serving

section("Serving rotation")
do {
    var m = newMatch(firstServer: .one)
    equal(m.server, .one, "A serves first")
    m.play("AAAA")
    equal(m.server, .two, "serve passes after each game")
    m.play("BBBB")
    equal(m.server, .one, "and back again")
}

do {
    // 3-3 with A serving the next (tie-break) point.
    var m = newMatch(firstServer: .one)
    m.play(games("ABABAB"))  // 6 games played, so A serves game 7 => the tie-break
    equal(m.phase, .setTiebreak, "into the tie-break")
    equal(m.server, .one, "A serves the first tie-break point")
    m.play("A")
    equal(m.server, .two, "B serves points 2 and 3")
    m.play("A")
    equal(m.server, .two, "still B")
    m.play("A")
    equal(m.server, .one, "A serves points 4 and 5")
    m.play("B")
    equal(m.server, .one, "still A")
}

do {
    var m = newMatch(firstServer: .one)
    m.play(games("ABABAB"))
    m.play("AAAAA")  // A serves first in the tie-break and wins it
    equal(m.server, .two, "after a tie-break the first server of it receives the next set")
}

// MARK: - Undo

section("Undo")
do {
    var m = newMatch()
    check(!m.canUndo, "nothing to undo at the start")
    m.play("AAA")
    let atForty = m
    m.play("A")
    equal(m.games[.one], 1, "game won")
    m.undo()
    equal(m, atForty, "undo restores the exact prior state, including the reset points")
    equal(m.games[.one], 0, "the game is given back")
    equal(m.pointDisplay(for: .one), "40", "back to 40")
}

do {
    // Undo across a set boundary, including the serve and tie-break bookkeeping.
    var m = newMatch()
    m.play(games("ABABAB"))
    m.play("AAAA")
    let beforeSetPoint = m
    m.play("A")
    equal(m.completedSets.count, 1, "set won on the tie-break")
    m.undo()
    equal(m, beforeSetPoint, "undo rewinds the completed set exactly")
    equal(m.phase, .setTiebreak, "back in the tie-break")
    equal(m.points, [4, 0], "tie-break points restored")
}

do {
    // Undoing everything must return to a pristine match.
    var m = newMatch()
    m.play(games("ABABAB") + "AAAAA" + games("BB"))
    while m.canUndo { m.undo() }
    equal(m, newMatch(), "undoing every point returns to the starting state")
}

// MARK: - Replay determinism

section("Replay determinism")
do {
    var m = newMatch(setsToWin: 3, matchTB: true)
    var seed: UInt64 = 42
    func nextBool() -> Bool {          // xorshift, so the run is reproducible
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return seed % 100 < 55
    }
    var guardCount = 0
    while !m.isOver && guardCount < 5000 {
        m.award(to: nextBool() ? .one : .two)
        guardCount += 1
    }
    check(m.isOver, "a random match terminates")
    let rebuilt = MatchState(config: m.config, pointLog: m.pointLog)
    equal(rebuilt, m, "rebuilding from the point log reproduces the state")

    let snapshot = MatchSnapshot(m)
    let data = try! JSONEncoder().encode(snapshot)
    let decoded = try! JSONDecoder().decode(MatchSnapshot.self, from: data)
    equal(decoded.state, m, "a match survives an encode/decode round trip")

    // Every event in the log points at a real point.
    equal(m.events.count, m.pointLog.count, "one history event per point")
    check(m.events.allSatisfy { m.pointLog[$0.id] == $0.winner }, "history winners match the log")
}

// MARK: - Invariants over an exhaustive sweep

section("Invariants across many random matches")
do {
    var seed: UInt64 = 7
    func rand() -> UInt64 {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return seed
    }
    var maxPoints = 0
    for trial in 0..<400 {
        let matchTB = trial % 2 == 0
        let setsToWin = trial % 3 == 0 ? 3 : 2
        var m = newMatch(setsToWin: setsToWin, matchTB: matchTB)
        var steps = 0
        while !m.isOver && steps < 5000 {
            m.award(to: rand() % 100 < 50 ? .one : .two)
            steps += 1

            check(m.games[.one] <= 4 && m.games[.two] <= 4, "games never exceed 4")
            check(!(m.games[.one] == 4 && m.games[.two] == 4), "a set never reaches 4-4")
            if m.phase == .game {
                check(m.points[.one] < 4 && m.points[.two] < 4, "a live game never shows 4 points")
            }
            if m.phase == .setTiebreak {
                check(m.points[.one] < 5 && m.points[.two] < 5, "a live set tie-break never reaches 5")
            }
            check(m.setsWon[.one] < setsToWin && m.setsWon[.two] < setsToWin || m.isOver,
                  "reaching the set target ends the match")
            check(m.completedSets.count <= setsToWin * 2 - 1, "never more sets than the format allows")
        }
        check(m.isOver, "trial \(trial) terminates")
        maxPoints = max(maxPoints, m.pointLog.count)

        // Set scores must be legal Fast4 results.
        for set in m.completedSets where !set.wasMatchTiebreak {
            let high = max(set.games[.one], set.games[.two])
            let low = min(set.games[.one], set.games[.two])
            equal(high, 4, "winning a set always means 4 games")
            check(low <= 3, "losing a set means at most 3 games")
            if low == 3 { check(set.tiebreakPoints != nil, "a 4-3 set must come from a tie-break") }
        }
    }
    print("  (longest match: \(maxPoints) points)")
}

print("\n\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    print("\(failures) FAILURES")
    exit(1)
}
print("All engine tests passed.")
