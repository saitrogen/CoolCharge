import Foundation
import Testing
@testable import CoolChargeCore

struct AppleChargingPolicyInspectorTests {
    @Test func emptyPolicyArchiveIsClear() throws {
        let data = try preferencesPlist(policies: [])

        #expect(AppleChargingPolicyInspector.inspect(plistData: data) == .clear)
    }

    @Test func nonEmptyPolicyArchiveIsActive() throws {
        let data = try preferencesPlist(policies: [["type": "chargeLimit"]])

        #expect(AppleChargingPolicyInspector.inspect(plistData: data) == .active(policyCount: 1))
    }

    @Test func missingOrMalformedPolicyDataIsUnavailable() throws {
        let missing = try PropertyListSerialization.data(
            fromPropertyList: ["bootSessionUUID": "test"],
            format: .binary,
            options: 0
        )
        let malformed = try PropertyListSerialization.data(
            fromPropertyList: ["policies": Data("not an archive".utf8)],
            format: .binary,
            options: 0
        )

        #expect(AppleChargingPolicyInspector.inspect(plistData: missing) == .unavailable)
        #expect(AppleChargingPolicyInspector.inspect(plistData: malformed) == .unavailable)
    }

    private func preferencesPlist(policies: [Any]) throws -> Data {
        let archivedPolicies = try NSKeyedArchiver.archivedData(
            withRootObject: policies,
            requiringSecureCoding: false
        )
        return try PropertyListSerialization.data(
            fromPropertyList: ["policies": archivedPolicies],
            format: .binary,
            options: 0
        )
    }
}
