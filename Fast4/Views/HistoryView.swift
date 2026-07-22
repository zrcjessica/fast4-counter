import SwiftUI

/// Point-by-point log, most recent first.
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let match: MatchState

    var body: some View {
        ZStack {
            GrassField()

            VStack(spacing: PixelTheme.unit * 3) {
                header

                if match.events.isEmpty {
                    Spacer()
                    Text("NO POINTS YET")
                        .font(.pixel(15))
                        .foregroundStyle(PixelTheme.pale)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: PixelTheme.unit * 4) {
                            ForEach(groups, id: \.setNumber) { group in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(header(for: group).uppercased())
                                        .font(.pixel(11))
                                        .foregroundStyle(PixelTheme.parchment)
                                        .padding(.horizontal, PixelTheme.unit * 3)
                                        .padding(.vertical, PixelTheme.unit * 2)
                                        .background(PixelTheme.ink)
                                        .padding(.leading, PixelTheme.unit * 3)
                                        .zIndex(1)

                                    VStack(spacing: 0) {
                                        ForEach(Array(group.events.reversed().enumerated()), id: \.element.id) { index, event in
                                            if index > 0 {
                                                Rectangle()
                                                    .fill(PixelTheme.pale)
                                                    .frame(height: PixelTheme.unit / 2)
                                            }
                                            EventRow(event: event, config: match.config)
                                        }
                                    }
                                    .padding(PixelTheme.unit * 3)
                                    .frame(maxWidth: .infinity)
                                    .pixelPanel()
                                }
                            }
                        }
                        .padding(.horizontal, PixelTheme.unit * 4)
                        .padding(.bottom, PixelTheme.unit * 6)
                    }
                }
            }
            .padding(.top, PixelTheme.unit * 4)
        }
    }

    private var header: some View {
        HStack {
            Text("POINT HISTORY")
                .font(.pixel(18))
                .foregroundStyle(PixelTheme.parchment)
                .shadow(color: PixelTheme.ink, radius: 0, x: PixelTheme.unit / 2, y: PixelTheme.unit / 2)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("DONE")
                    .font(.pixel(12))
                    .padding(.horizontal, PixelTheme.unit * 4)
                    .padding(.vertical, PixelTheme.unit * 2)
            }
            .buttonStyle(PixelButtonStyle(fill: PixelTheme.pale, depth: PixelTheme.unit))
        }
        .padding(.horizontal, PixelTheme.unit * 4)
    }

    private struct Group {
        var setNumber: Int
        var events: [MatchEvent]
    }

    /// Events bucketed by set, newest set first.
    private var groups: [Group] {
        var buckets: [Int: [MatchEvent]] = [:]
        for event in match.events {
            buckets[event.setNumber, default: []].append(event)
        }
        return buckets.keys.sorted(by: >).map { Group(setNumber: $0, events: buckets[$0] ?? []) }
    }

    private func header(for group: Group) -> String {
        guard group.setNumber <= match.completedSets.count else {
            return "Set \(group.setNumber) — in progress"
        }
        let set = match.completedSets[group.setNumber - 1]
        let name = match.config.displayName(set.winner)
        if set.wasMatchTiebreak, let tiebreak = set.tiebreakPoints {
            return "Match tie-break — \(name) \(tiebreak[.one])-\(tiebreak[.two])"
        }
        return "Set \(group.setNumber) — \(name) \(set.games[.one])-\(set.games[.two])"
    }
}

private struct EventRow: View {
    let event: MatchEvent
    let config: MatchConfig

    var body: some View {
        HStack(spacing: PixelTheme.unit * 3) {
            PixelIcon(rows: PixelArt.ball, color: PixelTheme.color(for: event.winner))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.displayName(event.winner).uppercased())
                    .font(.pixel(12))
                    .foregroundStyle(PixelTheme.ink)

                Text(detail)
                    .font(.pixel(10))
                    .foregroundStyle(event.wasDecidingPoint ? PixelTheme.alert : PixelTheme.green)
            }

            Spacer(minLength: PixelTheme.unit * 2)

            if let milestone = event.milestone {
                Text(milestone.uppercased())
                    .font(.pixel(10))
                    .foregroundStyle(PixelTheme.parchment)
                    .padding(.horizontal, PixelTheme.unit * 2)
                    .padding(.vertical, PixelTheme.unit)
                    .background(PixelTheme.green)
            } else {
                Text(event.scoreAfter)
                    .font(.pixel(15))
                    .foregroundStyle(PixelTheme.green)
            }
        }
        .padding(.vertical, PixelTheme.unit * 2)
    }

    private var detail: String {
        var parts = [event.isTiebreakPoint ? "Tie-break" : "Game \(event.gameNumber)"]
        parts.append("\(config.displayName(event.server)) serving")
        if event.wasDecidingPoint { parts.append("deciding point") }
        return parts.joined(separator: " · ")
    }
}
