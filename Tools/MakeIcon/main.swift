import AppKit
import CoreGraphics
import Foundation

// Draw small with antialiasing off, then upscale with nearest-neighbour so the
// result is true pixel art rather than a smooth vector shrunk down.
let grid = 32
let out = 1024
let cs = CGColorSpaceCreateDeviceRGB()

func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: cs, components: [
        Double((hex >> 16) & 0xFF) / 255,
        Double((hex >> 8) & 0xFF) / 255,
        Double(hex & 0xFF) / 255, 1,
    ])!
}

let soil = color(0x23450F)
let grass = color(0x2B5513)
let parchment = color(0xF4FAEA)
let green = color(0x5A9B2C)

let small = CGContext(data: nil, width: grid, height: grid, bitsPerComponent: 8,
                      bytesPerRow: 0, space: cs,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
small.setShouldAntialias(false)
small.interpolationQuality = .none

// Checkerboard field, 4px cells.
small.setFillColor(soil)
small.fill(CGRect(x: 0, y: 0, width: grid, height: grid))
small.setFillColor(grass)
for row in 0..<(grid / 4) {
    for col in 0..<(grid / 4) where (row + col).isMultiple(of: 2) {
        small.fill(CGRect(x: col * 4, y: row * 4, width: 4, height: 4))
    }
}

// Ball: a plotted disc, so the edge steps like a sprite.
let centre = 15.5
let radius = 11.0
func disc(_ fill: CGColor, _ r: Double) {
    small.setFillColor(fill)
    for y in 0..<grid {
        for x in 0..<grid {
            let dx = Double(x) + 0.5 - centre
            let dy = Double(y) + 0.5 - centre
            if (dx * dx + dy * dy).squareRoot() <= r {
                small.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }
}
disc(green, radius + 1.2)   // outline
disc(parchment, radius)

// A chunky "4" plotted by hand — a seam pattern is unreadable at 32x32.
let digit = [
    ".......##",
    "......###",
    ".....####",
    "....##.##",
    "...##..##",
    "..##...##",
    ".##....##",
    "#########",
    "#########",
    ".......##",
    ".......##",
    ".......##",
    ".......##",
]
small.setFillColor(green)
let digitWidth = digit[0].count
let originX = Int((centre - Double(digitWidth) / 2).rounded())
let originY = Int((centre - Double(digit.count) / 2).rounded())
for (row, line) in digit.enumerated() {
    for (col, character) in line.enumerated() where character == "#" {
        // Rows are listed top-down; the context's origin is bottom-left.
        small.fill(CGRect(x: originX + col, y: originY + (digit.count - 1 - row), width: 1, height: 1))
    }
}

let sprite = small.makeImage()!

let big = CGContext(data: nil, width: out, height: out, bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
big.interpolationQuality = .none
big.setShouldAntialias(false)
big.draw(sprite, in: CGRect(x: 0, y: 0, width: out, height: out))

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, big.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
