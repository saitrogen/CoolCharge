import Foundation

public enum AppleChargingPolicyStatus: Equatable, Sendable {
    case clear
    case active(policyCount: Int)
    case unavailable

    public var hasActivePolicy: Bool {
        if case .active = self { return true }
        return false
    }
}

public enum AppleChargingPolicyInspector {
    public static let systemPreferencesURL = URL(
        fileURLWithPath: "/Library/Preferences/com.apple.powerd.charging.plist"
    )

    public static func inspectSystemPreferences() -> AppleChargingPolicyStatus {
        guard let data = try? Data(contentsOf: systemPreferencesURL) else {
            return .unavailable
        }
        return inspect(plistData: data)
    }

    public static func inspect(plistData: Data) -> AppleChargingPolicyStatus {
        guard
            let propertyList = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            ),
            let root = propertyList as? [String: Any],
            let archivedPolicies = root["policies"] as? Data
        else {
            return .unavailable
        }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archivedPolicies)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }

            guard let policies = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? [Any] else {
                return .unavailable
            }
            return policies.isEmpty ? .clear : .active(policyCount: policies.count)
        } catch {
            return .unavailable
        }
    }
}
