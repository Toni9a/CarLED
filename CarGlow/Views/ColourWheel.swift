import SwiftUI

/// Hue/saturation wheel. Angle = hue, distance from centre = saturation.
struct ColourWheel: View {
    @Binding var hue: Double
    @Binding var saturation: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let angle = hue * 2 * .pi
            let knob = CGPoint(x: centre.x + cos(angle) * saturation * radius,
                               y: centre.y - sin(angle) * saturation * radius)
            ZStack {
                Circle()
                    .fill(AngularGradient(
                        gradient: Gradient(colors: (0...12).map { Color(hue: 1 - Double($0) / 12, saturation: 1, brightness: 1) }),
                        center: .center, angle: .degrees(0)))
                Circle()
                    .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: radius))
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .background(Circle().fill(Color(hue: hue, saturation: saturation, brightness: 1)))
                    .frame(width: 34, height: 34)
                    .shadow(radius: 4)
                    .position(knob)
            }
            .frame(width: size, height: size)
            .position(centre)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let dx = g.location.x - centre.x
                let dy = centre.y - g.location.y
                var a = atan2(dy, dx) / (2 * .pi)
                if a < 0 { a += 1 }
                hue = a
                saturation = min(1, hypot(dx, dy) / radius)
            })
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Colour wheel")
    }
}
