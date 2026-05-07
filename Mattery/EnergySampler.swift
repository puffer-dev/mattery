import Foundation

final class EnergySampler {
    private let store: EnergyStore
    private let interval: TimeInterval = 5 * 60
    private var timer: Timer?

    init(store: EnergyStore) {
        self.store = store
    }

    func start() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let entries = Self.runTop() else { return }
            self.store.append(timestamp: Date(), entries: entries)
        }
    }

    private static func runTop() -> [(command: String, power: Double)]? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        proc.arguments = ["-l", "2", "-s", "1", "-o", "power", "-n", "30", "-stats", "power,command"]
        let pipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = errPipe
        do {
            try proc.run()
        } catch {
            return nil
        }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return parse(text)
    }

    static func parse(_ text: String) -> [(command: String, power: Double)] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lastHeaderIdx: Int?
        for (i, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("POWER") && trimmed.contains("COMMAND") {
                lastHeaderIdx = i
            }
        }
        guard let startIdx = lastHeaderIdx else { return [] }

        var entries: [(String, Double)] = []
        for raw in lines.dropFirst(startIdx + 1) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let power = Double(parts[0]) else { continue }
            let command = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if command.isEmpty { continue }
            entries.append((command, power))
        }
        return entries
    }
}
