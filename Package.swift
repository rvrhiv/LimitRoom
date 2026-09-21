// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LimitRoom",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "AllowanceCore", targets: ["AllowanceCore"]),
    .library(name: "AllowanceConnectors", targets: ["AllowanceConnectors"]),
    .library(name: "AllowanceStorage", targets: ["AllowanceStorage"]),
    .library(name: "AllowanceRuntime", targets: ["AllowanceRuntime"]),
    .executable(name: "LimitRoom", targets: ["LimitRoom"]),
    .executable(name: "limitroom-claude-bridge", targets: ["ClaudeBridge"]),
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
  ],
  targets: [
    .target(name: "AllowanceCore"),
    .systemLibrary(name: "CSQLite"),
    .target(name: "AllowanceStorage", dependencies: ["AllowanceCore", "CSQLite"]),
    .target(name: "AllowanceConnectors", dependencies: ["AllowanceCore", "CSQLite"]),
    .target(
      name: "AllowanceRuntime",
      dependencies: ["AllowanceCore", "AllowanceStorage", "AllowanceConnectors"]),
    .executableTarget(name: "ClaudeBridge", dependencies: ["AllowanceCore"]),
    .executableTarget(
      name: "LimitRoom",
      dependencies: [
        "AllowanceCore", "AllowanceRuntime", "AllowanceStorage", "AllowanceConnectors",
        .product(name: "Sparkle", package: "Sparkle"),
      ], path: "App"),
  ]
)
