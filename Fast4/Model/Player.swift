import Foundation

/// One of the two sides in a match.
enum Player: Int, Codable, CaseIterable, Identifiable, Hashable {
    case one = 0
    case two = 1

    var id: Int { rawValue }

    var opponent: Player { self == .one ? .two : .one }
}

extension Array where Element == Int {
    /// Convenience subscripting of a two-element `[p1, p2]` array by `Player`.
    subscript(_ player: Player) -> Int {
        get { self[player.rawValue] }
        set { self[player.rawValue] = newValue }
    }
}
