// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "DictionaryCoder",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v10),
        .visionOS(.v2)
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
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "DictionaryCoderTests",
            dependencies: ["DictionaryCoder"],
            path: "Tests",
            exclude: ["Info.plist"]
        )
    ],
    swiftLanguageModes: [.v6]
)
