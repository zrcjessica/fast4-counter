import SwiftUI

struct SetupView: View {
    @Environment(MatchStore.self) private var store
    @State private var config: MatchConfig
    @FocusState private var focusedField: Player?

    init(config: MatchConfig) {
        _config = State(initialValue: config)
    }

    var body: some View {
        ZStack {
            GrassField()

            ScrollView {
                VStack(spacing: PixelTheme.unit * 4) {
                    title
                    playersPanel
                    formatPanel
                    servePanel
                    startButton
                    rulesPanel
                }
                .padding(.horizontal, PixelTheme.unit * 4)
                .padding(.vertical, PixelTheme.unit * 6)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Title

    private var title: some View {
        VStack(spacing: PixelTheme.unit) {
            Text("FAST 4")
                .font(.pixel(40))
                .foregroundStyle(PixelTheme.parchment)
                .shadow(color: PixelTheme.ink, radius: 0, x: PixelTheme.unit, y: PixelTheme.unit)
            Text("TENNIS SCOREBOARD")
                .font(.pixel(11))
                .foregroundStyle(PixelTheme.sprout)
        }
        .padding(.bottom, PixelTheme.unit)
    }

    // MARK: - Panels

    private var playersPanel: some View {
        SectionPanel(heading: "PLAYERS") {
            VStack(spacing: PixelTheme.unit * 3) {
                NameField(placeholder: "PLAYER 1", text: $config.playerOneName)
                    .focused($focusedField, equals: .one)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .two }

                NameField(placeholder: "PLAYER 2", text: $config.playerTwoName)
                    .focused($focusedField, equals: .two)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
        }
    }

    private var formatPanel: some View {
        SectionPanel(heading: "FORMAT") {
            VStack(alignment: .leading, spacing: PixelTheme.unit * 3) {
                PixelSegmented(
                    options: [("BEST OF 3", 2), ("BEST OF 5", 3)],
                    selection: $config.setsToWin
                )

                PixelCheckbox(
                    title: "Deciding set is a match tie-break",
                    isOn: $config.finalSetIsMatchTiebreak
                )

                Text(formatFooter)
                    .font(.pixel(11))
                    .foregroundStyle(PixelTheme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var servePanel: some View {
        SectionPanel(heading: "FIRST SERVE") {
            PixelSegmented(
                options: [
                    (config.displayName(.one).uppercased(), Player.one),
                    (config.displayName(.two).uppercased(), Player.two),
                ],
                selection: $config.firstServer
            )
        }
    }

    private var startButton: some View {
        Button {
            focusedField = nil
            store.start(config)
        } label: {
            Text("START MATCH")
                .font(.pixel(20))
                .padding(.vertical, PixelTheme.unit * 4)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelButtonStyle(fill: PixelTheme.leaf))
    }

    private var rulesPanel: some View {
        SectionPanel(heading: "FAST 4 RULES") {
            VStack(alignment: .leading, spacing: PixelTheme.unit * 3) {
                RuleRow("No-let serves", "A let is played as a normal point.")
                RuleRow("Sudden-death deuce", "At 40-40 the next point wins the game.")
                RuleRow("Short sets", "First to 4 games takes the set.")
                RuleRow("Set tie-break", "At 3-3, a tie-break to 5 — deciding point at 4-4.")
                if config.finalSetIsMatchTiebreak {
                    RuleRow(
                        "Match tie-break",
                        "At \(config.setsToWin - 1)-\(config.setsToWin - 1) in sets, a tie-break to 10 — deciding point at 9-9."
                    )
                }
            }
        }
    }

    private var formatFooter: String {
        let sets = config.setsToWin == 2 ? "3" : "5"
        guard config.finalSetIsMatchTiebreak else {
            return "Best of \(sets) sets. Every set is played out, with a tie-break to 5 at 3-3."
        }
        let decider = "\(config.setsToWin - 1)-\(config.setsToWin - 1)"
        return "Best of \(sets) sets. At \(decider) in sets the match is decided by a 10-point tie-break."
    }
}

// MARK: - Pieces

/// A titled parchment panel, with the heading sitting on its top edge.
private struct SectionPanel<Content: View>: View {
    let heading: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(heading)
                .font(.pixel(12))
                .foregroundStyle(PixelTheme.parchment)
                .padding(.horizontal, PixelTheme.unit * 3)
                .padding(.vertical, PixelTheme.unit * 2)
                .background(PixelTheme.ink)
                .padding(.leading, PixelTheme.unit * 3)
                .zIndex(1)

            content
                .padding(PixelTheme.unit * 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .pixelPanel()
        }
    }
}

private struct NameField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt:
            Text(placeholder)
                .font(.pixel(15))
                .foregroundStyle(PixelTheme.green.opacity(0.5))
        )
        .textFieldStyle(.plain)
        .font(.pixel(15))
        .foregroundStyle(PixelTheme.ink)
        .tint(PixelTheme.green)
        .autocorrectionDisabled()
        .padding(.horizontal, PixelTheme.unit * 3)
        .padding(.vertical, PixelTheme.unit * 3)
        .background {
            ZStack {
                Rectangle().fill(PixelTheme.ink)
                Rectangle().fill(PixelTheme.paper).padding(PixelTheme.unit)
            }
        }
    }
}

private struct RuleRow: View {
    let title: String
    let detail: String

    init(_ title: String, _ detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .top, spacing: PixelTheme.unit * 2) {
            PixelIcon(rows: PixelArt.ball, color: PixelTheme.leaf)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.pixel(12))
                    .foregroundStyle(PixelTheme.ink)
                Text(detail)
                    .font(.pixel(11))
                    .foregroundStyle(PixelTheme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
