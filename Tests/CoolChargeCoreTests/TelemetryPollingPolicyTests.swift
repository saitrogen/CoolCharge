import Testing
@testable import CoolChargeCore

struct TelemetryPollingPolicyTests {
    private let ordinaryReading = BatteryReading(
        percentage: 60,
        temperatureCelsius: 25,
        isConnected: true,
        isCharging: true,
        cycleCount: 10
    )

    @Test func visibleMenuUsesTwoSecondCadence() {
        let reading = BatteryReading(
            percentage: 60,
            temperatureCelsius: 34.5,
            isConnected: true,
            isCharging: true,
            cycleCount: 10
        )

        #expect(TelemetryPollingPolicy.interval(
            menuPresented: true,
            reading: reading,
            temperatureLimit: 35
        ) == 2)
    }

    @Test func connectedBatteryNearOrAboveLimitUsesFiveSecondCadence() {
        let nearLimit = BatteryReading(
            percentage: 60,
            temperatureCelsius: 33,
            isConnected: true,
            isCharging: true,
            cycleCount: 10
        )
        let aboveLimit = BatteryReading(
            percentage: 60,
            temperatureCelsius: 36,
            isConnected: true,
            isCharging: true,
            cycleCount: 10
        )

        #expect(TelemetryPollingPolicy.interval(
            menuPresented: false,
            reading: nearLimit,
            temperatureLimit: 35
        ) == 5)
        #expect(TelemetryPollingPolicy.interval(
            menuPresented: false,
            reading: aboveLimit,
            temperatureLimit: 35
        ) == 5)
    }

    @Test func ordinaryConnectedBackgroundUsesFifteenSecondCadence() {
        #expect(TelemetryPollingPolicy.interval(
            menuPresented: false,
            reading: ordinaryReading,
            temperatureLimit: 35
        ) == 15)
    }

    @Test func disconnectedBackgroundUsesFifteenSecondCadence() {
        let reading = BatteryReading(
            percentage: 60,
            temperatureCelsius: 34.5,
            isConnected: false,
            isCharging: false,
            cycleCount: 10
        )

        #expect(TelemetryPollingPolicy.interval(
            menuPresented: false,
            reading: reading,
            temperatureLimit: 35
        ) == 15)
    }
}
