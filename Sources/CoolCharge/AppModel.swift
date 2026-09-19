import CoolChargeCore
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var reading: BatteryReading?
    @Published private(set) var mode: ControlMode = .automatic
    @Published private(set) var message = "Reading battery…"
    @Published private(set) var backendAvailable = false
    @Published private(set) var isCommandPending = false
    @Published var targetPercentage: Int {
        didSet { defaults.set(targetPercentage, forKey: Keys.target) }
    }
    @Published var temperatureLimit: Double {
        didSet { defaults.set(temperatureLimit, forKey: Keys.temperature) }
    }

    private enum Keys {
        static let target = "targetPercentage"
        static let temperature = "temperatureLimit"
    }

    private let defaults = UserDefaults.standard
    private let reader = BatteryReader()
    private let batt = BattClient()
    private var timer: Timer?
    private var isRefreshing = false
    private var didSynchronizeBackend = false
    private var lastRequestedLimit: Int?

    private let resumeTemperatureDelta = 2.0
    private let minimumHoldDuration: TimeInterval = 300
    private let requiredCoolReadings = 2

    init() {
        let savedTarget = defaults.integer(forKey: Keys.target)
        targetPercentage = savedTarget == 0 ? 80 : savedTarget
        let savedTemperature = defaults.double(forKey: Keys.temperature)
        temperatureLimit = savedTemperature == 0 ? 35 : savedTemperature
        backendAvailable = false
        Task { @MainActor [weak self] in
            self?.start()
        }
    }

    var modeTitle: String {
        switch mode {
        case .automatic:
            guard let reading else { return "Automatic" }
            if !reading.isConnected { return "Automatic · On battery" }
            if reading.isCharging { return "Automatic · Charging" }
            if reading.percentage >= targetPercentage { return "Automatic · Target held" }
            return "Automatic · Ready"
        case .thermalHold: return "Automatic · Cooling hold"
        case .manualHold: return "Manual · Adapter hold"
        case .override(let target): return "Override · Charging to \(target)%"
        }
    }

    var resumeTemperature: Double {
        temperatureLimit - resumeTemperatureDelta
    }

    var menuBarTitle: String {
        guard let reading else { return "--°" }
        return String(format: "%.0f°", reading.temperatureCelsius)
    }

    var menuBarBatteryLevel: Double {
        guard let reading else { return 0 }
        return min(1, max(0, Double(reading.percentage) / 100))
    }

    var menuBarBadgeSymbol: String? {
        guard let reading, reading.isConnected else { return nil }
        return reading.isCharging ? "bolt.fill" : "powerplug.fill"
    }

    var menuBarAccessibilityLabel: String {
        guard let reading else { return "CoolCharge is reading the battery" }
        let powerState: String
        if !reading.isConnected {
            powerState = "on battery"
        } else if reading.isCharging {
            powerState = "charging"
        } else {
            powerState = "connected to power and not charging"
        }
        return String(
            format: "Battery %d percent, %@, temperature %.1f degrees Celsius",
            reading.percentage,
            powerState,
            reading.temperatureCelsius
        )
    }

    var stateSymbol: String {
        switch mode {
        case .thermalHold: "snowflake"
        case .manualHold: "pause.circle.fill"
        case .override: "bolt.fill"
        case .automatic:
            reading?.isCharging == true ? "bolt.fill" : "battery.75percent"
        }
    }

    var statusTitle: String {
        guard let reading else { return "Reading battery…" }
        switch mode {
        case .automatic:
            if !reading.isConnected { return "Running on battery" }
            if reading.isCharging { return "Charging automatically" }
            if reading.percentage >= targetPercentage { return "Charge target reached" }
            return "Automatic control ready"
        case .thermalHold:
            return "Cooling hold"
        case .manualHold:
            return "Manual adapter-only hold"
        case .override(let target):
            return "Charge Now to \(target)%"
        }
    }

    var statusDetail: String {
        guard let reading else { return "Waiting for a sensor reading." }
        switch mode {
        case .automatic:
            if !reading.isConnected {
                return "Connect the charger to charge toward \(targetPercentage)%."
            }
            if reading.isCharging {
                return "Charging toward \(targetPercentage)% · pauses at \(formattedTemperatureLimit)."
            }
            return "Adapter connected · firmware target \(targetPercentage)%."
        case .thermalHold(_, let heldAt, _):
            return "Charging paused at \(heldAt)% · adapter powers the Mac."
        case .manualHold(let heldAt):
            return "Held at \(heldAt)% until you select Resume Auto or Charge Now."
        case .override(let target):
            return "Temperature rule temporarily ignored until \(target)%."
        }
    }

    var thermalResumeDate: Date? {
        guard case .thermalHold(let since, _, _) = mode else { return nil }
        return since.addingTimeInterval(minimumHoldDuration)
    }

    func thermalProgressText(at date: Date) -> String? {
        guard
            let resumeDate = thermalResumeDate,
            let reading,
            case .thermalHold(_, _, let coolReadings) = mode
        else { return nil }
        let remaining = max(0, Int(ceil(resumeDate.timeIntervalSince(date))))
        if remaining > 0 {
            return String(format: "Earliest resume %d:%02d", remaining / 60, remaining % 60)
        }
        if reading.temperatureCelsius > resumeTemperature {
            return "Waiting to cool to \(formattedResumeTemperature)"
        }
        if coolReadings < requiredCoolReadings {
            return "Confirming cool reading \(coolReadings) of \(requiredCoolReadings)"
        }
        return "Ready to resume"
    }

    private var formattedTemperatureLimit: String {
        String(format: "%.0f°C", temperatureLimit)
    }

    private var formattedResumeTemperature: String {
        String(format: "%.0f°C", resumeTemperature)
    }

    var isHolding: Bool {
        switch mode {
        case .thermalHold, .manualHold: true
        case .automatic, .override: false
        }
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            defer { isRefreshing = false }
            do {
                let newReading = try await reader.read()
                reading = newReading
                backendAvailable = await batt.isReady()
                if backendAvailable {
                    message = "Monitoring every 15 seconds"
                } else if batt.isAvailable {
                    didSynchronizeBackend = false
                    lastRequestedLimit = nil
                    message = "batt is installed — daemon setup required"
                } else {
                    didSynchronizeBackend = false
                    lastRequestedLimit = nil
                    message = "Monitoring only — batt is not installed"
                }
                if backendAvailable && !didSynchronizeBackend {
                    let decision = policy.resumeAutomatic(reading: newReading)
                    didSynchronizeBackend = await execute(
                        decision,
                        successMessage: "Automatic temperature control enabled"
                    )
                } else {
                    await applyAutomaticPolicy(to: newReading)
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func holdNow() {
        guard let reading else { return }
        apply(policy.enterManualHold(reading: reading), successMessage: "Charging paused at \(reading.percentage)%")
    }

    func resumeAutomatic() {
        guard let reading else { return }
        apply(
            policy.resumeAutomatic(reading: reading),
            successMessage: "Automatic temperature control enabled"
        )
    }

    func chargeNow(to target: Int) {
        apply(
            policy.beginOverride(target: target),
            successMessage: "Temperature override active until \(target)%"
        )
    }

    func targetChanged() {
        guard case .automatic = mode, let reading else { return }
        apply(policy.resumeAutomatic(reading: reading), successMessage: "Charge target set to \(targetPercentage)%")
    }

    private var policy: ChargePolicy {
        ChargePolicy(
            targetPercentage: targetPercentage,
            temperatureLimit: temperatureLimit,
            resumeTemperatureDelta: resumeTemperatureDelta,
            minimumHoldDuration: minimumHoldDuration,
            requiredCoolReadings: requiredCoolReadings
        )
    }

    private func applyAutomaticPolicy(to reading: BatteryReading) async {
        let previousMode = mode
        let decision = policy.evaluate(reading: reading, mode: mode)
        guard decision != PolicyDecision(mode: mode, command: .none) else { return }
        if decision.command == .none {
            mode = decision.mode
            return
        }
        await execute(
            decision,
            successMessage: automaticMessage(for: decision, from: previousMode, reading: reading)
        )
    }

    private func automaticMessage(
        for decision: PolicyDecision,
        from previousMode: ControlMode,
        reading: BatteryReading
    ) -> String {
        if case .override = previousMode {
            return "Override complete — normal target restored"
        }
        if !reading.isConnected {
            return "Charger disconnected — normal target restored"
        }
        switch decision.command {
        case .hold:
            return "Temperature limit reached — charging paused"
        case .charge(let target):
            return "Battery cooled — charging resumed toward \(target)%"
        case .none:
            return "Automatic temperature control enabled"
        }
    }

    private func apply(_ decision: PolicyDecision, successMessage: String) {
        Task { await execute(decision, successMessage: successMessage) }
    }

    @discardableResult
    private func execute(_ decision: PolicyDecision, successMessage: String) async -> Bool {
        do {
            switch decision.command {
            case .none:
                break
            case .hold(let level), .charge(let level):
                if lastRequestedLimit != level {
                    guard !isCommandPending else { return false }
                    isCommandPending = true
                    defer { isCommandPending = false }
                    try await batt.setLimit(level)
                    lastRequestedLimit = level
                }
            }
            mode = decision.mode
            message = successMessage
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }
}
