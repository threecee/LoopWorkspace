import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: GlucoseViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                // B.2.d: ownership badge reflecting handoff state.
                HandoffOwnershipBadge(state: viewModel.handoffState)
                    .padding(.bottom, 4)
                if let reading = viewModel.latest {
                    Text("\(Int(reading.valueMgDl))")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(color(for: reading.valueMgDl))
                    HStack {
                        Text(trendSymbol(for: reading.trend))
                        Text(staleness(reading.timestamp))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                    Spacer(minLength: 8)
                    SparklineView(readings: viewModel.recent)
                        .frame(height: 28)
                } else {
                    Text("—")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                // B.2.c: phone↔watch connection visibility.
                Text(viewModel.phoneConnected ? "Phone: connected" : "Phone: out of range")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func color(for mgDl: Double) -> Color {
        switch mgDl {
        case ..<70: return .red
        case 70..<180: return .green
        default: return .orange
        }
    }

    private func trendSymbol(for trend: GlucoseTrend) -> String {
        switch trend {
        case .doubleUp:      return "↑↑"
        case .singleUp:      return "↑"
        case .fortyFiveUp:   return "↗"
        case .flat:          return "→"
        case .fortyFiveDown: return "↘"
        case .singleDown:    return "↓"
        case .doubleDown:    return "↓↓"
        case .notComputable: return "?"
        }
    }

    private func staleness(_ when: Date) -> String {
        let mins = Int(-when.timeIntervalSinceNow / 60)
        return mins <= 1 ? "now" : "\(mins) min ago"
    }
}

private struct SparklineView: View {
    let readings: [GlucoseReading]

    var body: some View {
        GeometryReader { geo in
            if readings.count >= 2 {
                let values = readings.map(\.valueMgDl)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = Swift.max(maxValue - minValue, 1)
                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) / CGFloat(values.count - 1) * geo.size.width
                        let y = geo.size.height * (1 - CGFloat((v - minValue) / range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(.primary, lineWidth: 1.5)
            }
        }
    }
}

#Preview {
    let vm = GlucoseViewModel()
    vm.latest = GlucoseReading(valueMgDl: 132, timestamp: Date(), trend: .flat, sensorId: "X")
    vm.recent = [110, 115, 120, 125, 130, 132].map {
        GlucoseReading(valueMgDl: $0, timestamp: Date(), trend: .flat, sensorId: "X")
    }
    return ContentView(viewModel: vm)
}
