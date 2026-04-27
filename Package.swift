// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Powermeter",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Powermeter", targets: ["Powermeter"])
    ],
    targets: [
        .executableTarget(
            name: "Powermeter",
            path: "Sources/Powermeter",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
