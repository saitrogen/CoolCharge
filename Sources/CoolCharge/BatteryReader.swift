import CoolChargeCore
import Foundation

enum BatteryReaderError: LocalizedError {
    case commandFailed(String)
    case incompleteReading

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message
        case .incompleteReading: "macOS returned an incomplete battery reading."
        }
    }
}

struct BatteryReader: Sendable {
    func read() async throws -> BatteryReading {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            process.arguments = ["-r", "-n", "AppleSmartBattery", "-d", "1"]
            process.standardOutput = output
            process.standardError = errors

            try process.run()
            process.waitUntilExit()

            let data = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8) ?? "Unable to read the battery."
                throw BatteryReaderError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            let text = String(decoding: data, as: UTF8.self)
            guard
                let percentage = Self.integer(named: "CurrentCapacity", in: text),
                let rawTemperature = Self.integer(named: "Temperature", in: text),
                let cycleCount = Self.integer(named: "CycleCount", in: text)
            else {
                throw BatteryReaderError.incompleteReading
            }

            return BatteryReading(
                percentage: percentage,
                temperatureCelsius: Double(rawTemperature) / 10 - 273.15,
                isConnected: Self.boolean(named: "ExternalConnected", in: text),
                isCharging: Self.boolean(named: "IsCharging", in: text),
                cycleCount: cycleCount,
                batteryCurrentMilliamps: Self.signedInteger(named: "Amperage", in: text) ?? 0,
                batteryVoltageVolts: Double(Self.integer(named: "Voltage", in: text) ?? 0) / 1_000,
                adapterInputWatts: Double(Self.integer(named: "SystemPowerIn", in: text) ?? 0) / 1_000,
                adapterRatedWatts: Self.integer(named: "Watts", in: text) ?? 0,
                systemLoadWatts: Double(Self.integer(named: "SystemLoad", in: text) ?? 0) / 1_000,
                currentCapacityMilliampHours: Self.integer(named: "AppleRawCurrentCapacity", in: text) ?? 0,
                fullCapacityMilliampHours: Self.integer(named: "AppleRawMaxCapacity", in: text) ?? 0,
                designCapacityMilliampHours: Self.integer(named: "DesignCapacity", in: text) ?? 0
            )
        }.value
    }

    private static func integer(named name: String, in text: String) -> Int? {
        capture(#"\"\#(name)\"\s*=\s*(\d+)"#, in: text).flatMap(Int.init)
    }

    private static func signedInteger(named name: String, in text: String) -> Int? {
        capture(#"\"\#(name)\"\s*=\s*(-?\d+)"#, in: text).flatMap(Int.init)
    }

    private static func boolean(named name: String, in text: String) -> Bool {
        capture(#"\"\#(name)\"\s*=\s*(Yes|No)"#, in: text) == "Yes"
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = expression.firstMatch(in: text, range: range),
            let captureRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[captureRange])
    }
}
