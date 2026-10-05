// swift-tools-version:6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault")
]

let package = Package(
    name: "DictionaryCoder",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "DictionaryCoder",
            targets: ["DictionaryCoder"]
        ),
        .library(
            name: "DictionaryCoderDynamic",
            type: .dynamic,
            targets: ["DictionaryCoder"]
        )
    ],
    targets: [
        .target(
            name: "DictionaryCoder",
            path: "Sources",
            exclude: ["Info.plist"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "DictionaryCoderTests",
            dependencies: ["DictionaryCoder"],
            path: "Tests",
            exclude: ["Info.plist"],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
