// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Oriel",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "OrielCore", targets: ["OrielCore"]),
        .executable(name: "Oriel", targets: ["Oriel"]),
        .executable(name: "OrielHelper", targets: ["OrielHelper"])
    ],
    targets: [
        .target(
            name: "OrielCore",
            path: "Sources/OrielCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("EventKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("MapKit")
            ]
        ),
        .executableTarget(
            name: "Oriel",
            dependencies: ["OrielCore"],
            path: "Sources/Oriel",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "OrielHelper",
            path: "Sources/OrielHelper",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "OrielTests",
            dependencies: ["OrielCore"],
            path: "Tests/OrielTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
