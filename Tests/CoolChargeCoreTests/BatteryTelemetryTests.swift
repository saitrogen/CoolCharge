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

    @Test func readsAdapterWattsWithoutUsingPowerOutWatts() {
        let telemetry = #"""
        "PowerOutDetails" = ({"Watts"=184,"Current"=35})
        "AdapterDetails" = {"FamilyCode"=0,"Watts"=86}
        """#

        #expect(BatteryTelemetry.integer(
            named: "Watts",
            inDictionaryNamed: "AdapterDetails",
            from: telemetry
        ) == 86)
    }

    @Test func missingAdapterWattsDoesNotFallBackToAnotherDictionary() {
        let telemetry = #"""
        "PowerOutDetails" = ({"Watts"=184})
        "AdapterDetails" = {"FamilyCode"=0}
        """#

        #expect(BatteryTelemetry.integer(
            named: "Watts",
            inDictionaryNamed: "AdapterDetails",
            from: telemetry
        ) == nil)
    }
}
