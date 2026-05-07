import Foundation
import Combine

final class EnergyStore: ObservableObject {
    struct Sample: Codable {
        let t: Date
        let entries: [Entry]
    }
    struct Entry: Codable {
        let n: String
        let v: Double
    }
    struct AggregatedRow: Identifiable {
        let id = UUID()
        let name: String
        let avgPower: Double
        let share: Double
    }

    struct HourlyAppUsage: Identifiable {
        let id = UUID()
        let hour: Date
        let app: String
        let value: Double
    }

    @Published private(set) var aggregated: [AggregatedRow] = []
    @Published private(set) var hourlyBreakdown: [HourlyAppUsage] = []
    @Published private(set) var observationStart: Date?

    private let url: URL
    private var samples: [Sample] = []
    private let windowSeconds: TimeInterval = 24 * 60 * 60
    private let queue = DispatchQueue(label: "com.puffer.Mattery.energyStore")

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dir = appSupport.appendingPathComponent("Mattery", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("samples.jsonl")
        load()
        recomputeOnMain()
    }

    func append(timestamp: Date, entries: [(command: String, power: Double)]) {
        queue.async { [weak self] in
            guard let self else { return }
            let sample = Sample(
                t: timestamp,
                entries: entries.map { Entry(n: $0.command, v: $0.power) }
            )
            self.samples.append(sample)
            self.trim()
            self.persist()
            DispatchQueue.main.async { self.recompute() }
        }
    }

    func refresh() {
        queue.async { [weak self] in
            self?.trim()
            DispatchQueue.main.async { self?.recompute() }
        }
    }

    private func trim() {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        samples.removeAll { $0.t < cutoff }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var loaded: [Sample] = []
        for line in text.split(separator: "\n") {
            if let s = try? decoder.decode(Sample.self, from: Data(line.utf8)) {
                loaded.append(s)
            }
        }
        samples = loaded
        trim()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var out = ""
        for s in samples {
            if let d = try? encoder.encode(s),
               let line = String(data: d, encoding: .utf8) {
                out += line + "\n"
            }
        }
        try? out.write(to: url, atomically: true, encoding: .utf8)
    }

    private func recomputeOnMain() {
        if Thread.isMainThread {
            recompute()
        } else {
            DispatchQueue.main.async { self.recompute() }
        }
    }

    private static let excludedCommands: Set<String> = ["top", "Mattery"]

    private func recompute() {
        let snapshot: [Sample] = queue.sync { samples }
        guard !snapshot.isEmpty else {
            aggregated = []
            hourlyBreakdown = []
            observationStart = nil
            return
        }
        observationStart = snapshot.first?.t

        var totalsByName: [String: Double] = [:]
        var countsByName: [String: Int] = [:]
        for s in snapshot {
            for e in s.entries where !Self.excludedCommands.contains(e.n) {
                totalsByName[e.n, default: 0] += e.v
                countsByName[e.n, default: 0] += 1
            }
        }
        let grandTotal = totalsByName.values.reduce(0, +)
        let rows: [AggregatedRow] = totalsByName.map { (name, total) in
            let count = countsByName[name] ?? 1
            return AggregatedRow(
                name: name,
                avgPower: total / Double(count),
                share: grandTotal > 0 ? total / grandTotal : 0
            )
        }
        aggregated = rows.sorted { $0.share > $1.share }

        hourlyBreakdown = Self.computeHourlyBreakdown(samples: snapshot, totals: totalsByName)
    }

    private static func computeHourlyBreakdown(
        samples: [Sample],
        totals: [String: Double]
    ) -> [HourlyAppUsage] {
        let calendar = Calendar.current
        var byHourApp: [Date: [String: Double]] = [:]
        for s in samples {
            let hour = calendar.dateInterval(of: .hour, for: s.t)?.start ?? s.t
            for e in s.entries where !excludedCommands.contains(e.n) {
                byHourApp[hour, default: [:]][e.n, default: 0] += e.v
            }
        }

        let topApps = Set(
            totals.sorted { $0.value > $1.value }.prefix(6).map { $0.key }
        )

        var result: [HourlyAppUsage] = []
        for (hour, apps) in byHourApp {
            var otherTotal: Double = 0
            for (name, value) in apps {
                if topApps.contains(name) {
                    result.append(HourlyAppUsage(hour: hour, app: name, value: value))
                } else {
                    otherTotal += value
                }
            }
            if otherTotal > 0 {
                result.append(HourlyAppUsage(hour: hour, app: "Other", value: otherTotal))
            }
        }
        return result.sorted { $0.hour < $1.hour }
    }

    var observationLabel: String {
        guard let start = observationStart else { return "No samples yet" }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= windowSeconds {
            return "Past 24h"
        }
        let h = Int(elapsed / 3600)
        let m = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        if h > 0 {
            return "Past \(h)h \(m)m of observed data"
        }
        return "Past \(m)m of observed data"
    }
}
