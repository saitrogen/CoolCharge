import Foundation

enum BattClientError: LocalizedError {
    case unavailable
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "The free batt backend is not installed. CoolCharge is monitoring only."
        case .commandFailed(let message):
            message
        }
    }
}

struct BattClient: Sendable {
    private let candidates = [
        "/opt/homebrew/bin/batt",
        "/usr/local/bin/batt"
    ]

    var executableURL: URL? {
        candidates
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(fileURLWithPath: $0) }
    }

    var isAvailable: Bool { executableURL != nil }

    func isReady() async -> Bool {
        guard isAvailable else { return false }
        return (try? await status()) != nil
    }

    func setLimit(_ percentage: Int) async throws {
        try await run(["limit", String(percentage)])
    }

    func status() async throws -> String {
        try await run(["status"])
    }

    @discardableResult
    private func run(_ arguments: [String]) async throws -> String {
        guard let executableURL else { throw BattClientError.unavailable }

        return try await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = errors

            try process.run()
            process.waitUntilExit()

            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            let standardOutput = String(decoding: outputData, as: UTF8.self)
            let standardError = String(decoding: errorData, as: UTF8.self)

            guard process.terminationStatus == 0 else {
                let message = standardError.isEmpty ? standardOutput : standardError
                throw BattClientError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return standardOutput
        }.value
    }
}
