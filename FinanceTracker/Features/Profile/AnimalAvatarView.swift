import SwiftUI

// Original vector portraits render locally and stay crisp at any avatar size.
struct AnimalAvatarView: View {
    let avatar: ProfileAvatar

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 100)
            let ink = Color(red: 0.12, green: 0.16, blue: 0.24)
            let background: Color
            let face: Color
            switch avatar {
            case .cat: background = Color(red: 0.22, green: 0.58, blue: 0.55); face = Color(red: 1, green: 0.84, blue: 0.57)
            case .dog: background = Color(red: 0.87, green: 0.39, blue: 0.38); face = Color(red: 1, green: 0.85, blue: 0.65)
            case .bird: background = Color(red: 0.25, green: 0.48, blue: 0.82); face = Color(red: 0.68, green: 0.87, blue: 1)
            case .tortoise: background = Color(red: 0.48, green: 0.39, blue: 0.73); face = Color(red: 0.66, green: 0.86, blue: 0.57)
            case .fish: background = Color(red: 0.95, green: 0.66, blue: 0.25); face = Color(red: 1, green: 0.88, blue: 0.61)
            }
            func ellipse(_ rect: CGRect, _ color: Color) {
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
            func triangle(_ points: [CGPoint], _ color: Color) {
                var path = Path()
                path.addLines(points)
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }
            context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .color(background))
            switch avatar {
            case .cat:
                triangle([CGPoint(x: 22, y: 39), CGPoint(x: 23, y: 10), CGPoint(x: 46, y: 27)], face)
                triangle([CGPoint(x: 54, y: 27), CGPoint(x: 77, y: 10), CGPoint(x: 78, y: 39)], face)
                triangle([CGPoint(x: 27, y: 29), CGPoint(x: 28, y: 17), CGPoint(x: 39, y: 26)], .pink.opacity(0.6))
                triangle([CGPoint(x: 61, y: 26), CGPoint(x: 72, y: 17), CGPoint(x: 73, y: 29)], .pink.opacity(0.6))
            case .dog:
                ellipse(CGRect(x: 14, y: 23, width: 25, height: 50), Color(red: 0.51, green: 0.31, blue: 0.23))
                ellipse(CGRect(x: 61, y: 23, width: 25, height: 50), Color(red: 0.51, green: 0.31, blue: 0.23))
            case .bird:
                triangle([CGPoint(x: 40, y: 30), CGPoint(x: 44, y: 10), CGPoint(x: 58, y: 27)], face)
            case .tortoise:
                ellipse(CGRect(x: 14, y: 65, width: 72, height: 40), face.opacity(0.7))
            case .fish:
                triangle([CGPoint(x: 29, y: 50), CGPoint(x: 10, y: 29), CGPoint(x: 10, y: 76)], face)
                triangle([CGPoint(x: 71, y: 50), CGPoint(x: 90, y: 29), CGPoint(x: 90, y: 76)], face)
            }
            ellipse(CGRect(x: 23, y: 24, width: 54, height: 60), face)
            for x in [CGFloat(39), CGFloat(61)] {
                ellipse(CGRect(x: x - 5, y: 43, width: 10, height: 13), ink)
                ellipse(CGRect(x: x - 2, y: 45, width: 3, height: 4), .white)
            }
            ellipse(CGRect(x: 28, y: 60, width: 10, height: 5), .pink.opacity(0.45))
            ellipse(CGRect(x: 62, y: 60, width: 10, height: 5), .pink.opacity(0.45))
            if avatar == .bird {
                triangle([CGPoint(x: 43, y: 57), CGPoint(x: 57, y: 57), CGPoint(x: 50, y: 66)], .orange)
            } else if avatar == .cat || avatar == .dog {
                ellipse(CGRect(x: 46, y: 57, width: 8, height: 6), ink)
            }
            var smile = Path()
            smile.move(to: CGPoint(x: 40, y: 68))
            smile.addQuadCurve(to: CGPoint(x: 60, y: 68), control: CGPoint(x: 50, y: 81))
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            if avatar == .cat {
                for side in [-1.0, 1.0] {
                    var whiskers = Path()
                    whiskers.move(to: CGPoint(x: 50 + side * 20, y: 60))
                    whiskers.addLine(to: CGPoint(x: 50 + side * 33, y: 56))
                    whiskers.move(to: CGPoint(x: 50 + side * 20, y: 65))
                    whiskers.addLine(to: CGPoint(x: 50 + side * 33, y: 66))
                    context.stroke(whiskers, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityLabel("\(avatar.name) avatar")
    }
}
