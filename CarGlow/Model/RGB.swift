import SwiftUI

struct RGB: Codable, Equatable, Hashable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let white = RGB(r: 255, g: 255, b: 255)

    var color: Color { Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
    var uiColor: UIColor { UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1) }

    init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }

    init(hue: Double, saturation: Double) {
        let c = UIColor(hue: hue, saturation: saturation, brightness: 1, alpha: 1)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0
        c.getRed(&rr, green: &gg, blue: &bb, alpha: nil)
        r = UInt8(clamping: Int((rr * 255).rounded()))
        g = UInt8(clamping: Int((gg * 255).rounded()))
        b = UInt8(clamping: Int((bb * 255).rounded()))
    }

    var hueSaturation: (hue: Double, saturation: Double) {
        var h: CGFloat = 0, s: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: nil, alpha: nil)
        return (Double(h), Double(s))
    }

    /// 0 = warm (candle), 1 = cool (daylight). For RGB-only strips.
    static func white(warmth t: Double) -> RGB {
        let warm = (r: 255.0, g: 147.0, b: 41.0)
        let cool = (r: 210.0, g: 225.0, b: 255.0)
        func mix(_ a: Double, _ b: Double) -> UInt8 { UInt8(clamping: Int((a + (b - a) * t).rounded())) }
        return RGB(r: mix(warm.r, cool.r), g: mix(warm.g, cool.g), b: mix(warm.b, cool.b))
    }
}
