import Foundation
import Testing
@testable import CoolChargeCore

struct ChargePolicyTests {
    private let policy = ChargePolicy(
        targetPercentage: 80,
        temperatureLimit: 35,
        resumeTemperatureDelta: 2,
        minimumHoldDuration: 300,
        requiredCoolReadings: 2
    )

    @Test func hotBatteryEntersThermalHoldAtCurrentLevel() {
        let now = Date(timeIntervalSince1970: 1_000)
        let decision = policy.evaluate(reading: reading(percent: 52, temperature: 35), mode: .automatic, now: now)

        #expect(decision == PolicyDecision(
            mode: .thermalHold(since: now, heldAt: 52, coolReadings: 0),
            command: .hold(at: 52)
        ))
    }

    @Test func thermalHoldDoesNotResumeBeforeFiveMinutes() {
        let start = Date(timeIntervalSince1970: 1_000)
        let decision = policy.evaluate(
            reading: reading(percent: 52, temperature: 33),
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 1),
            now: start.addingTimeInterval(299)
        )

        #expect(decision == PolicyDecision(
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 2),
            command: .none
        ))
    }

    @Test func thermalHoldDoesNotResumeInsideHysteresisBand() {
        let start = Date(timeIntervalSince1970: 1_000)
        let decision = policy.evaluate(
            reading: reading(percent: 52, temperature: 34),
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 1),
            now: start.addingTimeInterval(300)
        )

        #expect(decision == PolicyDecision(
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 0),
            command: .none
        ))
    }

    @Test func thermalHoldRequiresTwoConsecutiveCoolReadings() {
        let start = Date(timeIntervalSince1970: 1_000)
        let first = policy.evaluate(
            reading: reading(percent: 52, temperature: 33),
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 0),
            now: start.addingTimeInterval(300)
        )

        #expect(first == PolicyDecision(
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 1),
            command: .none
        ))

        let second = policy.evaluate(
            reading: reading(percent: 52, temperature: 32.9),
            mode: first.mode,
            now: start.addingTimeInterval(315)
        )

        #expect(second == PolicyDecision(mode: .automatic, command: .charge(to: 80)))
    }

    @Test func warmerReadingResetsCoolConfirmation() {
        let start = Date(timeIntervalSince1970: 1_000)
        let decision = policy.evaluate(
            reading: reading(percent: 52, temperature: 33.5),
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 1),
            now: start.addingTimeInterval(315)
        )

        #expect(decision == PolicyDecision(
            mode: .thermalHold(since: start, heldAt: 52, coolReadings: 0),
            command: .none
        ))
    }

    @Test func manualHoldStaysHeldEvenAfterCooling() {
        let decision = policy.evaluate(
            reading: reading(percent: 60, temperature: 30),
            mode: .manualHold(heldAt: 60)
        )

        #expect(decision == PolicyDecision(mode: .manualHold(heldAt: 60), command: .none))
    }

    @Test func overrideContinuesChargingWhileHot() {
        let decision = policy.evaluate(
            reading: reading(percent: 45, temperature: 42),
            mode: .override(target: 80)
        )

        #expect(decision == PolicyDecision(mode: .override(target: 80), command: .none))
    }

    @Test func completedTopUpRestoresNormalTarget() {
        let decision = policy.evaluate(
            reading: reading(percent: 100, temperature: 42),
            mode: .override(target: 100)
        )

        #expect(decision == PolicyDecision(mode: .automatic, command: .charge(to: 80)))
    }

    @Test func resumeAutomaticAboveTargetRestoresTargetEvenWhenHot() {
        let decision = policy.resumeAutomatic(
            reading: reading(percent: 90, temperature: 42)
        )

        #expect(decision == PolicyDecision(mode: .automatic, command: .charge(to: 80)))
    }

    @Test func disconnectRestoresNormalTarget() {
        let decision = policy.evaluate(
            reading: reading(percent: 60, temperature: 30, isConnected: false),
            mode: .manualHold(heldAt: 60)
        )

        #expect(decision == PolicyDecision(mode: .automatic, command: .charge(to: 80)))
    }

    private func reading(
        percent: Int,
        temperature: Double,
        isConnected: Bool = true
    ) -> BatteryReading {
        BatteryReading(
            percentage: percent,
            temperatureCelsius: temperature,
            isConnected: isConnected,
            isCharging: true,
            cycleCount: 17
        )
    }
}
