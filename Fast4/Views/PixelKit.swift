import SwiftUI
import CoreText

// A small pixel-art design system: palette, pixel font, chunky panels, beveled
// buttons and hand-plotted icons. Everything sits on a 4pt grid with square
// corners so the app reads as a 16-bit sports game rather than a modern app.
// The motifs are all tennis: a mown grass court behind everything, a net
// dividing the two players on the scoreboard, a racket in the title.

// MARK: - Palette

extension Color {
    init(pixel hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum PixelTheme {
    /// One "pixel" of the design grid.
    static let unit: CGFloat = 4

    static let ink      = Color(pixel: 0x1B3410)   // outlines and lettering
    static let soil     = Color(pixel: 0x23450F)   // court base
    static let grass    = Color(pixel: 0x2B5513)   // the lighter mown stripe
    static let green    = Color(pixel: 0x5A9B2C)
    static let leaf     = Color(pixel: 0x86C63F)
    static let sprout   = Color(pixel: 0xB4DE7C)
    static let pale     = Color(pixel: 0xDCEFC2)
    static let parchment = Color(pixel: 0xF4FAEA)
    static let paper    = Color(pixel: 0xFFFFFF)

    /// The one place the palette leaves green. A deciding point is the moment
    /// the game turns, so it gets the only red in the app.
    static let alert     = Color(pixel: 0xC8322A)
    static let alertEdge = Color(pixel: 0xF06052)

    static func color(for player: Player) -> Color {
        player == .one ? green : sprout
    }

    /// Lettering colour that reads on top of `color(for:)`.
    static func inkOn(_ player: Player) -> Color {
        player == .one ? parchment : ink
    }
}

// MARK: - Font

/// Silkscreen, chosen over softer pixel faces because its digits are
/// unambiguous — several otherwise-nicer pixel fonts render 5 almost identically
/// to S, which is fatal on a scoreboard. It has no lowercase: every glyph is a
/// capital, which suits the arcade look.
///
/// Only the regular weight is shipped. Silkscreen Bold closes the counter of
/// "4" so it reads as a solid blob, and this app is full of fours. Emphasis
/// comes from size and colour instead.
enum PixelFont {
    static let regular = "Silkscreen-Regular"

    /// Registers the bundled TTF with Core Text. Called once at launch, which
    /// avoids needing a hand-written Info.plist just for UIAppFonts.
    static func register() {
        guard let url = Bundle.main.url(forResource: regular, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func pixel(_ size: CGFloat) -> Font { .custom(PixelFont.regular, size: size) }
}

/// Text measurement for the pixel font.
///
/// Silkscreen is proportional — glyphs run from 0.375em ("I") to 0.875em ("M")
/// — so a shared font size can't be guessed from character counts. These
/// measure with Core Text instead.
enum PixelText {
    /// Width of `text` at a reference size of 100pt. Advance widths scale
    /// linearly, so any other size is a simple ratio of this.
    private static func referenceWidth(_ text: String) -> CGFloat {
        let font = CTFontCreateWithName(PixelFont.regular as CFString, 100, nil)
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// The largest size within `range` at which *every* string fits `available`.
    /// Used to give both players' names one identical size — sizing them
    /// independently makes the longer name render visibly smaller.
    static func fittingSize(for texts: [String], in available: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        guard available > 0, available.isFinite else { return range.upperBound }
        let widest = texts.map(referenceWidth).max() ?? 0
        guard widest > 0 else { return range.upperBound }
        return min(max(available / widest * 100, range.lowerBound), range.upperBound)
    }
}

// MARK: - Background

/// A grass court seen from above: mown stripes running the length of the court,
/// with the singles markings and the net laid over them. A grass court is
/// already white-on-green, so this stays inside the palette.
struct CourtField: View {
    var body: some View {
        Canvas { context, size in
            let unit = PixelTheme.unit
            /// Everything lands on the 4pt grid, so nothing renders half-lit.
            func snap(_ value: CGFloat) -> CGFloat { (value / unit).rounded() * unit }

            // Mown stripes, running baseline to baseline.
            let stripe: CGFloat = 32
            var x: CGFloat = 0
            var lit = false
            while x < size.width {
                if lit {
                    context.fill(
                        Path(CGRect(x: x, y: 0, width: stripe, height: size.height)),
                        with: .color(PixelTheme.grass)
                    )
                }
                lit.toggle()
                x += stripe
            }

            // Court markings, kept faint so the panels stay readable on top.
            let paint = PixelTheme.parchment.opacity(0.30)
            let left = snap(size.width * 0.11)
            let right = snap(size.width * 0.89)
            let top = snap(size.height * 0.06)
            let bottom = snap(size.height * 0.94)
            let net = snap((top + bottom) / 2)

            func horizontal(_ y: CGFloat, _ x0: CGFloat, _ x1: CGFloat, _ color: Color = paint) {
                context.fill(Path(CGRect(x: x0, y: snap(y), width: x1 - x0, height: unit)),
                             with: .color(color))
            }
            func vertical(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat, _ color: Color = paint) {
                context.fill(Path(CGRect(x: snap(x), y: y0, width: unit, height: y1 - y0)),
                             with: .color(color))
            }

            horizontal(top, left, right)          // baselines
            horizontal(bottom, left, right)
            vertical(left, top, bottom)           // sidelines
            vertical(right - unit, top, bottom)

            // The service line sits 21 feet from the net, of the 39 feet to the
            // baseline — so a little over half way out.
            let service = snap((net - top) * 21 / 39)
            horizontal(net - service, left, right)
            horizontal(net + service, left, right)
            vertical((left + right) / 2, net - service, net + service)

            // The net, brighter, with its posts standing outside the sidelines.
            horizontal(net, left - unit * 4, right + unit * 4,
                       PixelTheme.parchment.opacity(0.48))
        }
        .background(PixelTheme.soil)
        .ignoresSafeArea()
    }
}

/// A net in elevation: the white tape along the top, mesh hanging below it.
/// Used to separate the two players on the scoreboard — they are, after all,
/// on opposite sides of it.
struct PixelNet: View {
    var height: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            let unit = PixelTheme.unit
            let mesh = PixelTheme.green.opacity(0.45)

            // Tape.
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: unit)),
                         with: .color(PixelTheme.ink))

            // Mesh: a grid of cords hanging from the tape.
            var y = unit * 2
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: unit / 2)),
                             with: .color(mesh))
                y += unit * 2
            }
            var x: CGFloat = 0
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: unit, width: unit / 2, height: size.height - unit)),
                             with: .color(mesh))
                x += unit * 2
            }
        }
        .frame(height: height)
    }
}

// MARK: - Panel

/// The classic RPG dialog box: hard outline, inner bevel, flat fill.
struct PixelPanel: ViewModifier {
    var fill: Color = PixelTheme.parchment
    var edge: Color = PixelTheme.leaf
    var border: Color = PixelTheme.ink

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                Rectangle().fill(border)
                Rectangle().fill(edge).padding(PixelTheme.unit)
                Rectangle().fill(fill).padding(PixelTheme.unit * 2)
                // Top-left light, bottom-right shade — a one-pixel bevel.
                VStack(spacing: 0) {
                    Rectangle().fill(.white.opacity(0.55)).frame(height: PixelTheme.unit)
                    Spacer(minLength: 0)
                    Rectangle().fill(PixelTheme.ink.opacity(0.10)).frame(height: PixelTheme.unit)
                }
                .padding(PixelTheme.unit * 2)
            }
        }
    }
}

extension View {
    func pixelPanel(
        fill: Color = PixelTheme.parchment,
        edge: Color = PixelTheme.leaf,
        border: Color = PixelTheme.ink
    ) -> some View {
        modifier(PixelPanel(fill: fill, edge: edge, border: border))
    }
}

// MARK: - Buttons

/// A slab that sits above its own shadow and drops onto it when pressed.
struct PixelButtonStyle: ButtonStyle {
    var fill: Color = PixelTheme.leaf
    var label: Color = PixelTheme.ink
    var depth: CGFloat = PixelTheme.unit * 2
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        return configuration.label
            .foregroundStyle(label)
            .background {
                ZStack {
                    Rectangle().fill(PixelTheme.ink)
                    Rectangle().fill(fill).padding(PixelTheme.unit)
                    VStack(spacing: 0) {
                        Rectangle().fill(.white.opacity(0.45)).frame(height: PixelTheme.unit)
                        Spacer(minLength: 0)
                        Rectangle().fill(PixelTheme.ink.opacity(0.25)).frame(height: PixelTheme.unit)
                    }
                    .padding(PixelTheme.unit)
                }
            }
            .offset(x: pressed ? depth : 0, y: pressed ? depth : 0)
            .background(alignment: .topLeading) {
                Rectangle()
                    .fill(PixelTheme.ink.opacity(0.55))
                    .offset(x: depth, y: depth)
            }
            .animation(nil, value: pressed)
    }
}

// MARK: - Icons

/// A tiny bitmap, plotted by hand. "#" draws in `color`, "+" in `detail`
/// (racket strings, for instance); anything else is left blank.
struct PixelIcon: View {
    let rows: [String]
    var color: Color = PixelTheme.ink
    var detail: Color?

    var body: some View {
        Canvas { context, size in
            let columns = rows.map(\.count).max() ?? 1
            let scale = (min(size.width / CGFloat(columns), size.height / CGFloat(rows.count)))
                .rounded(.down)
            guard scale >= 1 else { return }
            let originX = ((size.width - scale * CGFloat(columns)) / 2).rounded()
            let originY = ((size.height - scale * CGFloat(rows.count)) / 2).rounded()
            let stringing = detail ?? color

            for (y, row) in rows.enumerated() {
                for (x, character) in row.enumerated() {
                    let ink: Color
                    switch character {
                    case "#": ink = color
                    case "+": ink = stringing
                    default: continue
                    }
                    context.fill(
                        Path(CGRect(x: originX + CGFloat(x) * scale,
                                    y: originY + CGFloat(y) * scale,
                                    width: scale, height: scale)),
                        with: .color(ink)
                    )
                }
            }
        }
    }
}

enum PixelArt {
    /// Head, stringbed and handle. "+" is the stringing, drawn as an open
    /// lattice — filling the head solid reads as a lollipop, not a racket.
    static let racket = [
        "...#####...",
        "..#.....#..",
        ".#.+.+.+.#.",
        "#..+.+.+..#",
        "#+++++++++#",
        "#..+.+.+..#",
        "#+++++++++#",
        ".#.+.+.+.#.",
        "..#.....#..",
        "...#####...",
        ".....#.....",
        ".....#.....",
        ".....#.....",
        "....###....",
    ]

    static let undo = [
        "....#....",
        "...##....",
        "..###....",
        ".####....",
        "#########",
        ".####....",
        "..###....",
        "...##....",
        "....#....",
    ]

    static let scroll = [
        "#########",
        "#.......#",
        "#.##.##.#",
        "#.......#",
        "#.##.##.#",
        "#.......#",
        "#.##.##.#",
        "#.......#",
        "#########",
    ]

    static let cog = [
        "..#...#..",
        "..#####..",
        ".#######.",
        "##.###.##",
        "###...###",
        "##.###.##",
        ".#######.",
        "..#####..",
        "..#...#..",
    ]

    static let trophy = [
        "###########",
        "#.........#",
        "##.......##",
        "##.......##",
        ".#.......#.",
        ".#########.",
        "....###....",
        "....###....",
        "..#######..",
        ".#########.",
        "###########",
    ]

    static let ball = [
        ".###.",
        "#####",
        "#####",
        "#####",
        ".###.",
    ]

    static let alert = [
        "....#....",
        "...###...",
        "...###...",
        "..##.##..",
        "..##.##..",
        ".###.###.",
        ".#######.",
        "###...###",
        "#########",
    ]
}

// MARK: - Controls

/// A row of slabs where exactly one is pressed in.
struct PixelSegmented<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: PixelTheme.unit * 2) {
            ForEach(options, id: \.value) { option in
                let chosen = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.pixel(size))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    PixelButtonStyle(
                        fill: chosen ? PixelTheme.green : PixelTheme.pale,
                        label: chosen ? PixelTheme.parchment : PixelTheme.ink,
                        depth: PixelTheme.unit
                    )
                )
            }
        }
    }
}

/// A checkbox with a pixel tick.
struct PixelCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    private static let tick = [
        ".......",
        "......#",
        ".....##",
        "#...###",
        "##.###.",
        ".#####.",
        "..###..",
        "...#...",
    ]

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: PixelTheme.unit * 3) {
                ZStack {
                    Rectangle().fill(PixelTheme.ink)
                    Rectangle().fill(isOn ? PixelTheme.green : PixelTheme.paper)
                        .padding(PixelTheme.unit)
                    if isOn {
                        PixelIcon(rows: Self.tick, color: PixelTheme.parchment)
                            .padding(PixelTheme.unit * 2)
                    }
                }
                .frame(width: 32, height: 32)

                Text(title)
                    .font(.pixel(12))
                    .foregroundStyle(PixelTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// An icon button for the top bar.
struct PixelIconButton: View {
    let art: [String]
    let accessibilityTitle: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PixelIcon(rows: art, color: PixelTheme.ink)
                .frame(width: 22, height: 22)
                .padding(9)
        }
        .buttonStyle(PixelButtonStyle(fill: PixelTheme.pale, depth: PixelTheme.unit, enabled: enabled))
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .accessibilityLabel(accessibilityTitle)
    }
}

// MARK: - Dialog

/// A modal in the app's own idiom — a system action sheet in the middle of a
/// pixel-art game looks like a bug.
struct PixelDialogModifier<Buttons: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    @ViewBuilder var buttons: Buttons

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    Rectangle()
                        .fill(PixelTheme.ink.opacity(0.75))
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }

                    VStack(spacing: PixelTheme.unit * 3) {
                        Text(title)
                            .font(.pixel(14))
                            .foregroundStyle(PixelTheme.ink)
                            .multilineTextAlignment(.center)

                        if let message {
                            Text(message)
                                .font(.pixel(10))
                                .foregroundStyle(PixelTheme.green)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        buttons
                    }
                    .padding(PixelTheme.unit * 5)
                    .frame(maxWidth: 320)
                    .pixelPanel()
                    .padding(PixelTheme.unit * 6)
                }
            }
        }
    }
}

extension View {
    func pixelDialog<Buttons: View>(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        modifier(PixelDialogModifier(isPresented: isPresented, title: title, message: message, buttons: buttons))
    }
}

struct PixelDialogButton: View {
    let title: String
    var fill: Color = PixelTheme.pale
    var label: Color = PixelTheme.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(12))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.vertical, PixelTheme.unit * 3)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelButtonStyle(fill: fill, label: label, depth: PixelTheme.unit))
    }
}

// MARK: - Haptics

#if canImport(UIKit)
import UIKit

enum Haptics {
    @MainActor static func point() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    @MainActor static func milestone() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    @MainActor static func undo() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
#else
enum Haptics {
    @MainActor static func point() {}
    @MainActor static func milestone() {}
    @MainActor static func undo() {}
}
#endif
