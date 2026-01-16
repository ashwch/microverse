#if DEBUG
import SwiftUI

struct WeatherIconGallery: View {
    enum Renderer: String, CaseIterable, Identifiable {
        case sfSymbols = "SF Symbols"
        case microverseCanvas = "Microverse"

        var id: String { rawValue }
    }

    enum SymbolMode: String, CaseIterable, Identifiable {
        case hierarchical = "Hierarchical"
        case monochrome = "Monochrome"

        var id: String { rawValue }
    }

    enum PreviewScale: String, CaseIterable, Identifiable {
        case oneX = "1×"
        case twoX = "2×"

        var id: String { rawValue }

        var value: CGFloat {
            switch self {
            case .oneX: return 1
            case .twoX: return 2
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var renderer: Renderer = .sfSymbols
    @State private var symbolMode: SymbolMode = .hierarchical
    @State private var scale: PreviewScale = .oneX
    @State private var isDaylight: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space3) {
            header

            controls

            ScrollView {
                VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space4) {
                    conditionGrid
                    eventGrid
                }
                .padding(.top, MicroverseDesign.Layout.space2)
            }
        }
        .padding(MicroverseDesign.Layout.space4)
        .frame(width: 720, height: 560)
        .background(MicroverseDesign.Colors.backgroundDark)
    }

    private var header: some View {
        HStack {
            Text("Weather icon gallery")
                .font(MicroverseDesign.Typography.title)
                .foregroundColor(.white)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    private var controls: some View {
        HStack(spacing: MicroverseDesign.Layout.space3) {
            Picker("Renderer", selection: $renderer) {
                ForEach(Renderer.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            if renderer == .sfSymbols {
                Picker("Mode", selection: $symbolMode) {
                    ForEach(SymbolMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Picker("Scale", selection: $scale) {
                ForEach(PreviewScale.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Toggle("Day", isOn: $isDaylight)
                .toggleStyle(.switch)
                .foregroundColor(.white.opacity(0.7))

            Spacer()
        }
    }

    private var conditionGrid: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            Text("CONDITIONS")
                .font(MicroverseDesign.Typography.label)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.8)

            Grid(alignment: .leading, horizontalSpacing: MicroverseDesign.Layout.space3, verticalSpacing: MicroverseDesign.Layout.space2) {
                GridRow {
                    gridHeader("Condition")
                    gridHeader("Compact")
                    gridHeader("Widget")
                    gridHeader("Popover")
                    gridHeader("Symbol")
                }

                ForEach(WeatherConditionBucket.allCases, id: \.rawValue) { bucket in
                    GridRow {
                        Text(bucket.displayName)
                            .font(MicroverseDesign.Typography.caption)
                            .foregroundColor(.white.opacity(0.85))

                        glyph(bucket: bucket, context: .compact)
                        glyph(bucket: bucket, context: .widget)
                        glyph(bucket: bucket, context: .popover)

                        Text(bucket.symbolName(isDaylight: isDaylight))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    Divider()
                        .background(.white.opacity(0.08))
                }
            }
            .padding(MicroverseDesign.Layout.space3)
            .background(MicroverseDesign.cardBackground())
        }
    }

    private var eventGrid: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            Text("ANNOUNCEMENTS")
                .font(MicroverseDesign.Typography.label)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.8)

            Grid(alignment: .leading, horizontalSpacing: MicroverseDesign.Layout.space3, verticalSpacing: MicroverseDesign.Layout.space2) {
                GridRow {
                    gridHeader("Event")
                    gridHeader("Icon")
                    gridHeader("Symbol")
                }

                ForEach(sampleEvents, id: \.id) { event in
                    GridRow {
                        Text(event.title)
                            .font(MicroverseDesign.Typography.caption)
                            .foregroundColor(.white.opacity(0.85))

                        Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: event, isDaylight: isDaylight))
                            .font(.system(size: 12 * scale.value, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .symbolRenderingMode(symbolMode == .hierarchical ? .hierarchical : .monochrome)
                            .frame(width: 24 * scale.value, height: 18 * scale.value)

                        Text(MicroverseWeatherAnnouncement.symbolName(for: event, isDaylight: isDaylight))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    Divider()
                        .background(.white.opacity(0.08))
                }
            }
            .padding(MicroverseDesign.Layout.space3)
            .background(MicroverseDesign.cardBackground())
        }
    }

    private func gridHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(MicroverseDesign.Typography.label)
            .foregroundColor(.white.opacity(0.45))
    }

    private enum PreviewContext {
        case compact
        case widget
        case popover

        var fontSize: CGFloat {
            switch self {
            case .compact: return 10
            case .widget: return 12
            case .popover: return 22
            }
        }

        var frame: CGFloat {
            switch self {
            case .compact: return 12
            case .widget: return 16
            case .popover: return 28
            }
        }
    }

    private func glyph(bucket: WeatherConditionBucket, context: PreviewContext) -> some View {
        let renderMode: WeatherRenderMode = {
            switch renderer {
            case .sfSymbols:
                return .off
            case .microverseCanvas:
                return .low(fps: 0) // static Canvas preview (no TimelineView ticks)
            }
        }()

        let size = context.frame * scale.value
        let fontSize = context.fontSize * scale.value

        return MicroverseWeatherGlyph(bucket: bucket, isDaylight: isDaylight, renderMode: renderMode)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(.white.opacity(0.88))
            .symbolRenderingMode(symbolMode == .hierarchical ? .hierarchical : .monochrome)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: max(4, 6 * scale.value)))
    }

    private var sampleEvents: [WeatherEvent] {
        let now = Date()
        return [
            WeatherEvent(
                id: "precipStart",
                kind: .precipStart,
                startTime: now.addingTimeInterval(25 * 60),
                severity: 0.7,
                title: "Precipitation soon",
                valueC: nil,
                fromBucket: nil,
                toBucket: .rain
            ),
            WeatherEvent(
                id: "precipStop",
                kind: .precipStop,
                startTime: now.addingTimeInterval(20 * 60),
                severity: 0.5,
                title: "Clearing",
                valueC: nil,
                fromBucket: .rain,
                toBucket: .cloudy
            ),
            WeatherEvent(
                id: "shiftFog",
                kind: .conditionShift,
                startTime: now.addingTimeInterval(2 * 60 * 60),
                severity: 0.6,
                title: "Fog",
                valueC: nil,
                fromBucket: .cloudy,
                toBucket: .fog
            ),
            WeatherEvent(
                id: "tempDrop",
                kind: .tempDrop,
                startTime: now.addingTimeInterval(2 * 60 * 60),
                severity: 0.7,
                title: "Cooling down",
                valueC: -6,
                fromBucket: nil,
                toBucket: nil
            ),
            WeatherEvent(
                id: "tempRise",
                kind: .tempRise,
                startTime: now.addingTimeInterval(2 * 60 * 60),
                severity: 0.7,
                title: "Warming up",
                valueC: 6,
                fromBucket: nil,
                toBucket: nil
            ),
        ]
    }
}

#endif

