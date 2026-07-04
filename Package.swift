// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpoilerDelay",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "SpoilerDelay", targets: ["SpoilerDelay"])
    ],
    targets: [
        .executableTarget(
            name: "SpoilerDelay",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("Contacts"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(name: "SpoilerDelayTests", dependencies: ["SpoilerDelay"])
    ],
    swiftLanguageModes: [.v6]
)
