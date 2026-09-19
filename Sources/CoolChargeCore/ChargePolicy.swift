import Foundation

public struct BatteryReading: Equatable, Sendable {
    public var percentage: Int
    public var temperatureCelsius: Double
    public var isConnected: Bool
    public var isCharging: Bool
    public var cycleCount: Int
    public var batteryCurrentMilliamps: Int
    public var batteryVoltageVolts: Double
    public var adapterInputWatts: Double
    public var adapterRatedWatts: Int
    public var systemLoadWatts: Double
    public var currentCapacityMilliampHours: Int
    public var fullCapacityMilliampHours: Int
    public var designCapacityMilliampHours: Int

    public init(
        percentage: Int,
        temperatureCelsius: Double,
        isConnected: Bool,
        isCharging: Bool,
        cycleCount: Int,
        batteryCurrentMilliamps: Int = 0,
        batteryVoltageVolts: Double = 0,
        adapterInputWatts: Double = 0,
        adapterRatedWatts: Int = 0,
        systemLoadWatts: Double = 0,
        currentCapacityMilliampHours: Int = 0,
        fullCapacityMilliampHours: Int = 0,
        designCapacityMilliampHours: Int = 0
    ) {
        self.percentage = percentage
        self.temperatureCelsius = temperatureCelsius
        self.isConnected = isConnected
        self.isCharging = isCharging
        self.cycleCount = cycleCount
        self.batteryCurrentMilliamps = batteryCurrentMilliamps
        self.batteryVoltageVolts = batteryVoltageVolts
        self.adapterInputWatts = adapterInputWatts
        self.adapterRatedWatts = adapterRatedWatts
        self.systemLoadWatts = systemLoadWatts
        self.currentCapacityMilliampHours = currentCapacityMilliampHours
        self.fullCapacityMilliampHours = fullCapacityMilliampHours
        self.designCapacityMilliampHours = designCapacityMilliampHours
    }

    public var batteryPowerWatts: Double {
        Double(batteryCurrentMilliamps) * batteryVoltageVolts / 1_000
    }

    public var healthPercentage: Int {
        guard designCapacityMilliampHours > 0 else { return 0 }
        let raw = Double(fullCapacityMilliampHours) / Double(designCapacityMilliampHours) * 100
        return min(100, Int(raw.rounded()))
    }
}

public enum ControlMode: Equatable, Sendable {
    case automatic
    case thermalHold(since: Date, heldAt: Int, coolReadings: Int)
    case manualHold(heldAt: Int)
    case override(target: Int)
}

public enum PolicyCommand: Equatable, Sendable {
    case none
    case hold(at: Int)
    case charge(to: Int)
}

public struct PolicyDecision: Equatable, Sendable {
    public var mode: ControlMode
    public var command: PolicyCommand

    public init(mode: ControlMode, command: PolicyCommand) {
        self.mode = mode
        self.command = command
    }
}

public struct ChargePolicy: Sendable {
    public var targetPercentage: Int
    public var temperatureLimit: Double
    public var resumeTemperatureDelta: Double
    public var minimumHoldDuration: TimeInterval
    public var requiredCoolReadings: Int

    public init(
        targetPercentage: Int = 80,
        temperatureLimit: Double = 35,
        resumeTemperatureDelta: Double = 2,
        minimumHoldDuration: TimeInterval = 300,
        requiredCoolReadings: Int = 2
    ) {
        self.targetPercentage = targetPercentage
        self.temperatureLimit = temperatureLimit
        self.resumeTemperatureDelta = max(0, resumeTemperatureDelta)
        self.minimumHoldDuration = minimumHoldDuration
        self.requiredCoolReadings = max(1, requiredCoolReadings)
    }

    public var resumeTemperature: Double {
        temperatureLimit - resumeTemperatureDelta
    }

    public func evaluate(
        reading: BatteryReading,
        mode: ControlMode,
        now: Date = Date()
    ) -> PolicyDecision {
        guard reading.isConnected else {
            return PolicyDecision(mode: .automatic, command: .charge(to: targetPercentage))
        }

        switch mode {
        case .override(let target):
            if reading.percentage >= target {
                return PolicyDecision(mode: .automatic, command: .charge(to: targetPercentage))
            }
            return PolicyDecision(mode: mode, command: .none)

        case .manualHold:
            return PolicyDecision(mode: mode, command: .none)

        case .thermalHold(let since, let heldAt, let coolReadings):
            let heldLongEnough = now.timeIntervalSince(since) >= minimumHoldDuration
            let updatedCoolReadings = reading.temperatureCelsius <= resumeTemperature
                ? min(requiredCoolReadings, coolReadings + 1)
                : 0
            if heldLongEnough && updatedCoolReadings >= requiredCoolReadings {
                return PolicyDecision(mode: .automatic, command: .charge(to: targetPercentage))
            }
            return PolicyDecision(
                mode: .thermalHold(since: since, heldAt: heldAt, coolReadings: updatedCoolReadings),
                command: .none
            )

        case .automatic:
            return automaticDecision(for: reading, now: now)
        }
    }

    public func enterManualHold(reading: BatteryReading) -> PolicyDecision {
        let level = clamped(reading.percentage)
        return PolicyDecision(mode: .manualHold(heldAt: level), command: .hold(at: level))
    }

    public func resumeAutomatic(reading: BatteryReading, now: Date = Date()) -> PolicyDecision {
        if reading.isConnected
            && reading.temperatureCelsius >= temperatureLimit
            && reading.percentage < targetPercentage
        {
            let level = clamped(reading.percentage)
            return PolicyDecision(
                mode: .thermalHold(since: now, heldAt: level, coolReadings: 0),
                command: .hold(at: level)
            )
        }
        return PolicyDecision(mode: .automatic, command: .charge(to: targetPercentage))
    }

    public func beginOverride(target: Int) -> PolicyDecision {
        let safeTarget = clamped(target)
        return PolicyDecision(mode: .override(target: safeTarget), command: .charge(to: safeTarget))
    }

    private func automaticDecision(for reading: BatteryReading, now: Date) -> PolicyDecision {
        if reading.temperatureCelsius >= temperatureLimit && reading.percentage < targetPercentage {
            let level = clamped(reading.percentage)
            return PolicyDecision(
                mode: .thermalHold(since: now, heldAt: level, coolReadings: 0),
                command: .hold(at: level)
            )
        }
        return PolicyDecision(mode: .automatic, command: .none)
    }

    private func clamped(_ value: Int) -> Int {
        min(100, max(10, value))
    }
}
