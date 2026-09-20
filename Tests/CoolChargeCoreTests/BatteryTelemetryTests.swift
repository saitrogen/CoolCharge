import Testing
@testable import CoolChargeCore

struct BatteryTelemetryTests {
    @Test func decodesUnsignedTwoComplementDischargeValue() {
        #expect(BatteryTelemetry.signedInt(from: "18446744073709551198") == -418)
    }

    @Test func decodesOrdinaryPositiveValue() {
        #expect(BatteryTelemetry.signedInt(from: "3190") == 3190)
    }

    @Test func decodesExplicitNegativeDecimalValue() {
        #expect(BatteryTelemetry.signedInt(from: "-418") == -418)
    }

    @Test func rejectsMalformedAndOutOfRangeValues() {
        #expect(BatteryTelemetry.signedInt(from: "not-a-number") == nil)
        #expect(BatteryTelemetry.signedInt(from: "18446744073709551616") == nil)
    }
}
