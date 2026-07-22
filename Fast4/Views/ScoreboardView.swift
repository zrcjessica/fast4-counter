import SwiftUI

struct ScoreboardView: View {
    @Environment(MatchStore.self) private var store
    let match: MatchState

    @State private var showingHistory = false
    @State private var confirmingEnd = false
    @State private var showingOptions = false
    /// Width the layout actually gives the player names, measured so both can
    /// share one font size.
    @State private var nameWidth: CGFloat = 0

    var body: some View {
        ZStack {
            GrassField()

            VStack(spacing: PixelTheme.unit * 3) {
                topBar
                situationBar

                Spacer(minLength: PixelTheme.unit * 2)
                scoreboard
                Spacer(minLength: PixelTheme.unit * 2)

                if match.isOver {
                    resultPanel
                } else {
                    scoringButtons
                }

                undoButton
            }
            .padding(.horizontal, PixelTheme.unit * 3)
            .padding(.bottom, PixelTheme.unit * 3)
        }
        // A scoreboard is useless if it sleeps between points.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $showingHistory) {
            HistoryView(match: match)
                .presentationBackground(PixelTheme.soil)
        }
        .pixelDialog(isPresented: $showingOptions, title: "MATCH OPTIONS") {
            VStack(spacing: PixelTheme.unit * 2) {
                PixelDialogButton(title: "REMATCH", fill: PixelTheme.leaf) {
                    showingOptions = false
                    store.rematch()
                }
                PixelDialogButton(title: "END MATCH", fill: PixelTheme.ink, label: PixelTheme.parchment) {
                    showingOptions = false
                    if match.isOver { store.end() } else { confirmingEnd = true }
                }
                PixelDialogButton(title: "BACK") { showingOptions = false }
            }
        }
        .pixelDialog(
            isPresented: $confirmingEnd,
            title: "END THIS MATCH?",
            message: "The current score will be discarded."
        ) {
            VStack(spacing: PixelTheme.unit * 2) {
                PixelDialogButton(title: "END MATCH", fill: PixelTheme.ink, label: PixelTheme.parchment) {
                    confirmingEnd = false
                    store.end()
                }
                PixelDialogButton(title: "KEEP PLAYING", fill: PixelTheme.leaf) { confirmingEnd = false }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: PixelTheme.unit * 2) {
            PixelIconButton(
                art: PixelArt.scroll,
                accessibilityTitle: "Point history",
                enabled: !match.events.isEmpty
            ) { showingHistory = true }

            Spacer(minLength: 0)

            Text("FAST 4")
                .font(.pixel(30))
                .foregroundStyle(PixelTheme.parchment)
                .shadow(color: PixelTheme.ink, radius: 0, x: PixelTheme.unit / 2, y: PixelTheme.unit / 2)

            Spacer(minLength: 0)

            PixelIconButton(art: PixelArt.cog, accessibilityTitle: "Match options") {
                showingOptions = true
            }
        }
    }

    // MARK: - Situation

    private var situationBar: some View {
        VStack(spacing: PixelTheme.unit) {
            if !match.isOver {
                Text(match.situationDescription.uppercased())
                    .font(.pixel(16))
                    .foregroundStyle(PixelTheme.pale)
                    .multilineTextAlignment(.center)
            }

            if match.isDecidingPoint {
                HStack(spacing: PixelTheme.unit * 2) {
                    PixelIcon(rows: PixelArt.alert, color: PixelTheme.parchment)
                        .frame(width: 16, height: 16)
                    Text(decidingLabel)
                        .font(.pixel(14))
                        .foregroundStyle(PixelTheme.parchment)
                }
                .padding(.horizontal, PixelTheme.unit * 4)
                .padding(.vertical, PixelTheme.unit * 2)
                .pixelPanel(fill: PixelTheme.alert, edge: PixelTheme.alertEdge)
            }
        }
    }

    private var decidingLabel: String {
        switch match.phase {
        case .game: "SUDDEN DEATH!"
        case .setTiebreak, .matchTiebreak: "DECIDING POINT!"
        case .matchOver: ""
        }
    }

    // MARK: - Scoreboard

    private var scoreboard: some View {
        VStack(spacing: 0) {
            ColumnCaptions(match: match)

            ScoreRow(match: match, player: .one, nameSize: nameFontSize)

            Rectangle()
                .fill(PixelTheme.ink)
                .frame(height: PixelTheme.unit)
                .padding(.horizontal, PixelTheme.unit * 2)

            ScoreRow(match: match, player: .two, nameSize: nameFontSize)
        }
        .padding(PixelTheme.unit * 2)
        .pixelPanel()
        .onPreferenceChange(NameWidthKey.self) { nameWidth = $0 }
    }

    /// One size for both names, from whichever is wider.
    private var nameFontSize: CGFloat {
        PixelText.fittingSize(
            for: Player.allCases.map { match.config.displayName($0).uppercased() },
            in: nameWidth,
            range: 16...30
        )
    }

    // MARK: - Scoring

    private var scoringButtons: some View {
        VStack(spacing: PixelTheme.unit * 3) {
            ForEach(Player.allCases) { player in
                Button {
                    let wasOver = match.isOver
                    store.award(to: player)
                    if let updated = store.match,
                       updated.isOver != wasOver || updated.events.last?.milestone != nil {
                        Haptics.milestone()
                    } else {
                        Haptics.point()
                    }
                } label: {
                    HStack(spacing: PixelTheme.unit * 3) {
                        if match.server == player {
                            PixelIcon(rows: PixelArt.ball, color: PixelTheme.inkOn(player))
                                .frame(width: 14, height: 14)
                        }
                        Text(match.config.displayName(player).uppercased())
                            .font(.pixel(18))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text("+1")
                            .font(.pixel(22))
                    }
                    .padding(.horizontal, PixelTheme.unit * 5)
                    .frame(maxWidth: .infinity, minHeight: 86)
                }
                .buttonStyle(
                    PixelButtonStyle(
                        fill: PixelTheme.color(for: player),
                        label: PixelTheme.inkOn(player)
                    )
                )
                .accessibilityLabel("Point to \(match.config.displayName(player))")
            }
        }
    }

    private var undoButton: some View {
        Button {
            store.undo()
            Haptics.undo()
        } label: {
            HStack(spacing: PixelTheme.unit * 3) {
                PixelIcon(rows: PixelArt.undo, color: PixelTheme.ink)
                    .frame(width: 16, height: 16)
                Text("UNDO LAST POINT")
                    .font(.pixel(12))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(PixelButtonStyle(fill: PixelTheme.pale, depth: PixelTheme.unit, enabled: match.canUndo))
        .disabled(!match.canUndo)
        .opacity(match.canUndo ? 1 : 0.45)
    }

    // MARK: - Result

    private var resultPanel: some View {
        let winner = match.winner ?? .one
        return VStack(spacing: PixelTheme.unit * 2) {
            PixelIcon(rows: PixelArt.trophy, color: PixelTheme.green)
                .frame(width: 44, height: 44)

            Text("\(match.config.displayName(winner).uppercased()) WINS!")
                .font(.pixel(18))
                .foregroundStyle(PixelTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(match.finalScoreDescription)
                .font(.pixel(15))
                .foregroundStyle(PixelTheme.green)

            HStack(spacing: PixelTheme.unit * 3) {
                Button {
                    store.rematch()
                } label: {
                    Text("REMATCH")
                        .font(.pixel(12))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelButtonStyle(fill: PixelTheme.green, label: PixelTheme.parchment, depth: PixelTheme.unit))

                Button {
                    store.end()
                } label: {
                    Text("NEW MATCH")
                        .font(.pixel(12))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelButtonStyle(fill: PixelTheme.pale, depth: PixelTheme.unit))
            }
            .padding(.top, PixelTheme.unit)
        }
        .padding(PixelTheme.unit * 5)
        .frame(maxWidth: .infinity)
        .pixelPanel()
    }
}

// MARK: - Row

/// Shared column geometry so the captions line up with the numbers.
private enum ScoreColumns {
    static let set: CGFloat = 34
    static let games: CGFloat = 38
    static let points: CGFloat = 90
    static let spacing = PixelTheme.unit * 2
}

private struct ColumnCaptions: View {
    let match: MatchState

    var body: some View {
        HStack(spacing: ScoreColumns.spacing) {
            Spacer(minLength: 0)

            ForEach(match.completedSets) { set in
                Text("S\(set.index + 1)")
                    .lineLimit(1)
                    .frame(width: ScoreColumns.set)
            }

            if match.phase != .matchTiebreak && !match.isOver {
                Text("GMS").frame(width: ScoreColumns.games)
            }

            if !match.isOver {
                Text("PTS").frame(width: ScoreColumns.points, alignment: .trailing)
            }
        }
        .font(.pixel(14))
        .foregroundStyle(PixelTheme.green.opacity(0.75))
        .padding(.horizontal, PixelTheme.unit * 2)
        .padding(.bottom, PixelTheme.unit)
        .accessibilityHidden(true)
    }
}

/// Reports the width the HStack gives the name, so both rows can agree on a size.
private struct NameWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct ScoreRow: View {
    let match: MatchState
    let player: Player
    let nameSize: CGFloat

    var body: some View {
        HStack(spacing: ScoreColumns.spacing) {
            PixelIcon(rows: PixelArt.ball, color: PixelTheme.green)
                .frame(width: 12, height: 12)
                .opacity(match.server == player && !match.isOver ? 1 : 0)
                .accessibilityLabel(match.server == player ? "Serving" : "")

            Text(match.config.displayName(player).uppercased())
                .font(.pixel(nameSize))
                .foregroundStyle(PixelTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: NameWidthKey.self, value: proxy.size.width)
                    }
                }

            ForEach(match.completedSets) { set in
                Text(setValue(set))
                    .font(.pixel(22))
                    .foregroundStyle(set.winner == player ? PixelTheme.ink : PixelTheme.green.opacity(0.45))
                    // No minimumScaleFactor: it would make this compressible, and
                    // the greedy name column would squeeze it to nothing. The
                    // column is wide enough for a two-digit tie-break score.
                    .lineLimit(1)
                    .frame(width: ScoreColumns.set)
            }

            if match.phase != .matchTiebreak && !match.isOver {
                Text("\(match.games[player])")
                    .font(.pixel(30))
                    .foregroundStyle(PixelTheme.ink)
                    .frame(width: ScoreColumns.games)
            }

            if !match.isOver {
                Text(match.pointDisplay(for: player))
                    .font(.pixel(52))
                    .foregroundStyle(PixelTheme.green)
                    .frame(width: ScoreColumns.points, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.12), value: match.points[player])
            }
        }
        .padding(.horizontal, PixelTheme.unit * 2)
        .padding(.vertical, PixelTheme.unit * 5)
        .accessibilityElement(children: .combine)
    }

    private func setValue(_ set: CompletedSet) -> String {
        if set.wasMatchTiebreak, let tiebreak = set.tiebreakPoints {
            return "\(tiebreak[player])"
        }
        return "\(set.games[player])"
    }
}
