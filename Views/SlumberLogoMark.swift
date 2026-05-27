import SwiftUI

// Crescent moon + stars logo mark, used in the dashboard header and anywhere
// a branded icon is needed. Matches the app icon design.

struct SlumberLogoMark: View {
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            // Rounded-square background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0a0c14"), Color(hex: "#152060")],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

            // Glow
            Circle()
                .fill(Color("AccentBlue").opacity(0.25))
                .frame(width: size * 0.72, height: size * 0.72)
                .blur(radius: size * 0.14)

            // Crescent
            CrescentShape()
                .fill(
                    Color(red: 0.88, green: 0.92, blue: 1.0),
                    style: FillStyle(eoFill: true)
                )
                .frame(width: size * 0.54, height: size * 0.54)
                .offset(x: -size * 0.02, y: -size * 0.01)

            // Stars
            StarField(size: size)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Crescent

private struct CrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let or = min(rect.width, rect.height) / 2
        let ir = or * 0.795
        let dx = or * 0.415
        let dy = or * 0.140

        var p = Path()
        p.addEllipse(in: CGRect(x: cx-or,    y: cy-or,    width: or*2, height: or*2))
        p.addEllipse(in: CGRect(x: cx-ir+dx, y: cy-ir-dy, width: ir*2, height: ir*2))
        return p
    }
}

// MARK: - Star field

private struct StarField: View {
    let size: CGFloat

    // (x, y) as fractions of `size`, radius in points, alpha
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.72, 0.34, 1.9, 1.00),
        (0.68, 0.55, 1.1, 0.75),
        (0.76, 0.55, 1.3, 0.85),
        (0.74, 0.22, 1.2, 0.70),
        (0.66, 0.22, 0.9, 0.60),
    ]

    var body: some View {
        Canvas { ctx, _ in
            for (fx, fy, r, a) in stars {
                let rect = CGRect(
                    x: size * fx - r, y: size * fy - r,
                    width: r * 2,     height: r * 2
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        SlumberLogoMark(size: 32)
        SlumberLogoMark(size: 48)
        SlumberLogoMark(size: 64)
        SlumberLogoMark(size: 96)
    }
    .padding()
    .background(Color(hex: "#0a0c14"))
}
