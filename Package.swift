// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CoolCharge",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CoolCharge", targets: ["CoolCharge"])
    ],
    targets: [
        .target(name: "CoolChargeCore"),
        .executableTarget(
            name: "CoolCharge",
            dependencies: ["CoolChargeCore"]
        ),
        .testTarget(
            name: "CoolChargeCoreTests",
            dependencies: ["CoolChargeCore"]
        )
    ]
)
