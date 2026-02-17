// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "appAgent",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // iOS-App-Produkt für SwiftUI, Team-ID übernimmt Bitrise
        .iOSApplication(
            name: "appAgent",
            targets: ["appAgent"],
            bundleIdentifier: "at.co.weinmann.appAgent",
            displayVersion: "1.0",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor"
        )
    ],
    dependencies: [
        // Hier können weitere Swift-Pakete eingebunden werden
        // .package(url: "https://github.com/username/PackageName.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "appAgent",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
