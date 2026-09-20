import Foundation

/// Chooses how frequently CoolCharge should refresh battery telemetry.
///
/// The menu needs a responsive display while it is visible. In the background,
/// the battery changes slowly, so the normal cadence is deliberately lower. A
/// connected battery close to the configured thermal threshold gets a middle
/// cadence so a pause is not delayed unnecessarily.
public enum TelemetryPollingPolicy {
    public static let visibleInterval: TimeInterval = 2
    public static let nearLimitInterval: TimeInterval = 5
    public static let backgroundInterval: TimeInterval = 15
    public static let defaultNearLimitDelta: Double = 2

    public static func interval(
        menuPresented: Bool,
        reading: BatteryReading?,
        temperatureLimit: Double,
        nearLimitDelta: Double = defaultNearLimitDelta
    ) -> TimeInterval {
        if menuPresented {
            return visibleInterval
        }

        guard let reading,
              reading.isConnected,
              reading.temperatureCelsius >= temperatureLimit - max(0, nearLimitDelta)
        else {
            return backgroundInterval
        }

        return nearLimitInterval
    }
}
