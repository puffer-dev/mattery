import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject var store: EnergyStore
    @State private var displayMode: DisplayMode = .chart

    enum DisplayMode: String, CaseIterable, Identifiable {
        case chart = "Chart"
        case list = "List"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Picker("", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(8)

            Divider()

            Group {
                switch displayMode {
                case .chart:
                    BatteryUsageChartView(store: store)
                case .list:
                    BatteryUsageListView(store: store)
                }
            }

            Divider()

            HStack {
                Text(store.observationLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { store.refresh() }
            }
            .padding(8)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

private struct BatteryUsageListView: View {
    @ObservedObject var store: EnergyStore
    @State private var sortOrder: [KeyPathComparator<EnergyStore.AggregatedRow>] = [
        KeyPathComparator(\.share, order: .reverse)
    ]

    private var sortedRows: [EnergyStore.AggregatedRow] {
        store.aggregated.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedRows, sortOrder: $sortOrder) {
            TableColumn("App / Process", value: \.name) { row in
                Text(row.name).lineLimit(1)
            }
            TableColumn("Avg Energy Impact", value: \.avgPower) { row in
                Text(String(format: "%.1f", row.avgPower))
                    .monospacedDigit()
            }
            TableColumn("Share", value: \.share) { row in
                Text(String(format: "%.1f%%", row.share * 100))
                    .monospacedDigit()
            }
        }
    }
}

private struct BatteryUsageChartView: View {
    @ObservedObject var store: EnergyStore

    var body: some View {
        if store.hourlyBreakdown.isEmpty {
            VStack {
                Spacer()
                Text("No samples yet")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(store.hourlyBreakdown) { item in
                BarMark(
                    x: .value("Hour", item.hour, unit: .hour),
                    y: .value("Energy Impact", item.value)
                )
                .foregroundStyle(by: .value("App", item.app))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing)
            }
            .chartLegend(position: .bottom, alignment: .center, spacing: 8)
            .padding(12)
        }
    }
}
