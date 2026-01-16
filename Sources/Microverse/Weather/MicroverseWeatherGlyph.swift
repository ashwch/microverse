import SwiftUI

struct MicroverseWeatherGlyph: View {
    let bucket: WeatherConditionBucket
    let isDaylight: Bool
    let renderMode: WeatherRenderMode

    var body: some View {
        if renderMode == .off {
            Image(systemName: bucket.symbolName(isDaylight: isDaylight))
        } else if let interval = renderMode.interval {
            TimelineView(.periodic(from: .now, by: interval)) { timeline in
                canvas(t: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(t: 0)
        }
    }

    @ViewBuilder
    private func canvas(t: TimeInterval) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            draw(context: &context, size: size, t: t)
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch bucket {
        case .clear:
            drawClear(context: &context, size: size, t: t, isDaylight: isDaylight)
        case .cloudy:
            drawCloud(context: &context, size: size, t: t, opacity: 0.85)
        case .rain:
            drawCloud(context: &context, size: size, t: t, opacity: 0.80)
            drawRain(context: &context, size: size, t: t)
        case .snow:
            drawCloud(context: &context, size: size, t: t, opacity: 0.80)
            drawSnow(context: &context, size: size, t: t)
        case .fog:
            drawFog(context: &context, size: size, t: t)
        case .thunder:
            drawCloud(context: &context, size: size, t: t, opacity: 0.80)
            drawThunder(context: &context, size: size, t: t)
        case .wind:
            drawWind(context: &context, size: size, t: t)
        case .unknown:
            drawCloud(context: &context, size: size, t: t, opacity: 0.60)
        }
    }

    // MARK: - Primitives

    private func drawClear(context: inout GraphicsContext, size: CGSize, t: TimeInterval, isDaylight: Bool) {
        let w = size.width
        let h = size.height
        let center = CGPoint(x: w * 0.52, y: h * 0.48)

        if isDaylight {
            let r = min(w, h) * 0.22
            let pulse = CGFloat(0.04 * sin(t * 0.7))
            let rr = r * (1 + pulse)

            let sun = Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2))
            context.fill(sun, with: .color(.white.opacity(0.90)))

            // Slow ray shimmer (deferential; reads premium at low FPS).
            let rayAlpha = 0.18 + 0.06 * (sin(t * 0.6) + 1) * 0.5
            let rayLen = r * 1.85

            var rays = Path()
            for i in 0..<8 {
                let a = CGFloat(i) * (.pi / 4) + CGFloat(t * 0.05)
                let p1 = CGPoint(x: center.x + cos(a) * (r * 1.25), y: center.y + sin(a) * (r * 1.25))
                let p2 = CGPoint(x: center.x + cos(a) * rayLen, y: center.y + sin(a) * rayLen)
                rays.move(to: p1)
                rays.addLine(to: p2)
            }
            context.stroke(rays, with: .color(.white.opacity(rayAlpha)), lineWidth: max(1, h * 0.04))
        } else {
            // Simple moon crescent.
            let r = min(w, h) * 0.22
            let moon = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.fill(moon, with: .color(.white.opacity(0.86)))

            let cut = Path(ellipseIn: CGRect(x: center.x - r * 0.55, y: center.y - r * 0.90, width: r * 2, height: r * 2))
            context.blendMode = .destinationOut
            context.fill(cut, with: .color(.black))
            context.blendMode = .normal
        }
    }

    private func drawCloud(context: inout GraphicsContext, size: CGSize, t: TimeInterval, opacity: Double) {
        let w = size.width
        let h = size.height
        let drift = CGFloat(sin(t * 0.25)) * (w * 0.03)

        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: w * 0.18 + drift, y: h * 0.52, width: w * 0.64, height: h * 0.22),
            cornerSize: CGSize(width: h * 0.12, height: h * 0.12)
        )
        p.addEllipse(in: CGRect(x: w * 0.22 + drift, y: h * 0.40, width: w * 0.26, height: h * 0.26))
        p.addEllipse(in: CGRect(x: w * 0.40 + drift, y: h * 0.34, width: w * 0.30, height: h * 0.30))
        p.addEllipse(in: CGRect(x: w * 0.58 + drift, y: h * 0.40, width: w * 0.26, height: h * 0.26))

        context.fill(p, with: .color(.white.opacity(opacity)))
    }

    private func drawRain(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let w = size.width
        let h = size.height
        let count = 10
        let speed = h * 0.55

        var path = Path()
        for i in 0..<count {
            let seed = Double(i) * 0.37
            let x = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * w * 0.70 + w * 0.15
            let phase = (t * 0.9 + seed).truncatingRemainder(dividingBy: 1.0)
            let y0 = h * 0.60 + CGFloat(phase) * speed
            let y1 = y0 + h * 0.10

            path.move(to: CGPoint(x: x, y: y0))
            path.addLine(to: CGPoint(x: x - w * 0.02, y: y1))
        }

        context.stroke(path, with: .color(.white.opacity(0.40)), lineWidth: max(1, h * 0.04))
    }

    private func drawSnow(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let w = size.width
        let h = size.height
        let count = 8

        for i in 0..<count {
            let seed = Double(i) * 0.51
            let xBase = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * w * 0.70 + w * 0.15
            let sway = CGFloat(sin(t * 0.8 + seed * 6.0)) * (w * 0.03)
            let phase = (t * 0.20 + seed).truncatingRemainder(dividingBy: 1.0)
            let y = h * 0.62 + CGFloat(phase) * (h * 0.35)

            let r = max(1, h * 0.04)
            let rect = CGRect(x: xBase + sway - r, y: y - r, width: 2 * r, height: 2 * r)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55)))
        }
    }

    private func drawFog(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        // Fog reads better with a cloud cap + bands (similar to SF Symbols' silhouette).
        drawCloud(context: &context, size: size, t: t, opacity: 0.70)

        let w = size.width
        let h = size.height

        for band in 0..<3 {
            let y = h * (0.62 + CGFloat(band) * 0.12)
            let drift = CGFloat(sin(t * 0.20 + Double(band))) * (w * 0.04)
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: w * 0.12 + drift, y: y, width: w * 0.76, height: h * 0.08),
                cornerSize: CGSize(width: h * 0.05, height: h * 0.05)
            )
            context.fill(p, with: .color(.white.opacity(0.16)))
        }
    }

    private func drawThunder(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let w = size.width
        let h = size.height

        // Rare flash (deterministic, no RNG). Only shows when we're ticking.
        let flash = (Int(t) % 19 == 0) && ((t - floor(t)) < 0.12)
        if flash {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.10)))
        }

        var bolt = Path()
        bolt.move(to: CGPoint(x: w * 0.56, y: h * 0.56))
        bolt.addLine(to: CGPoint(x: w * 0.48, y: h * 0.76))
        bolt.addLine(to: CGPoint(x: w * 0.60, y: h * 0.76))
        bolt.addLine(to: CGPoint(x: w * 0.50, y: h * 0.92))

        context.stroke(bolt, with: .color(.white.opacity(0.55)), lineWidth: max(1, h * 0.05))
    }

    private func drawWind(context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let w = size.width
        let h = size.height
        let phase = CGFloat(sin(t * 0.4)) * (w * 0.02)

        func band(y: CGFloat, alpha: Double) {
            var p = Path()
            p.move(to: CGPoint(x: w * 0.20 + phase, y: y))
            p.addCurve(
                to: CGPoint(x: w * 0.82 + phase, y: y),
                control1: CGPoint(x: w * 0.40 + phase, y: y - h * 0.08),
                control2: CGPoint(x: w * 0.62 + phase, y: y + h * 0.08)
            )
            context.stroke(p, with: .color(.white.opacity(alpha)), lineWidth: max(1, h * 0.05))
        }

        band(y: h * 0.44, alpha: 0.35)
        band(y: h * 0.58, alpha: 0.25)
        band(y: h * 0.72, alpha: 0.20)
    }
}
