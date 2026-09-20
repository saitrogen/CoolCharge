import Foundation

/// Decoders for numeric values exposed by Apple's battery telemetry.
public enum BatteryTelemetry {
    /// Decodes an amperage value from `ioreg`.
    ///
    /// On Apple silicon, a negative amperage can be emitted as the decimal
    /// representation of its `UInt64` two's-complement bit pattern (for
    /// example, `18446744073709551198` represents `-418`). Explicit signed
    /// decimal values and ordinary positive values are supported as well.
    public static func signedInt(from text: String) -> Int? {
        if text.hasPrefix("-") {
            return Int64(text).flatMap(Int.init)
        }

        guard let unsigned = UInt64(text) else { return nil }
        return Int64(bitPattern: unsigned).toIntIfRepresentable
    }
}

private extension Int64 {
    var toIntIfRepresentable: Int? {
        Int(exactly: self)
    }
}
