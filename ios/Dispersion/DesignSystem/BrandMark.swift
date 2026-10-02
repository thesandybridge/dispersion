import SwiftUI

/// Shared geometry with BrandMark.svg and the app icon renderer.
struct BrandMark: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Ellipse()
                    .stroke(lineWidth: side * 0.035)
                    .frame(width: side * 0.68, height: side * 0.38)
                    .position(x: side * 0.5, y: side * 0.65)
                Ellipse()
                    .stroke(lineWidth: side * 0.035)
                    .frame(width: side * 0.46, height: side * 0.24)
                    .position(x: side * 0.5, y: side * 0.65)
                Capsule()
                    .frame(width: side * 0.05, height: side * 0.46)
                    .position(x: side * 0.5, y: side * 0.43)
                Path { flag in
                    flag.move(to: CGPoint(x: side * 0.5, y: side * 0.2))
                    flag.addLine(to: CGPoint(x: side * 0.77, y: side * 0.31))
                    flag.addLine(to: CGPoint(x: side * 0.5, y: side * 0.42))
                    flag.closeSubpath()
                }
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
