// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "appAgent",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Das Modul, das die App bereitstellt
        .executable(
            name: "appAgent",
            targets: ["appAgent"]
        )
    ],
    dependencies: [
        // Optional: hier könntest du weitere Swift-Pakete einbinden, z.B. für erweitertes Syntax-Highlighting
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
