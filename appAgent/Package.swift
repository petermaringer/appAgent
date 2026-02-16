// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "appAgent",
  platforms: [.iOS(.v17)],
  products: [
    .executable(name: "appAgent", targets: ["appAgent"])
  ],
  targets: [
    .executableTarget(
      name: "appAgent",
      dependencies: []
    )
  ]
)
