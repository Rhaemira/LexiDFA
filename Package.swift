// swift-tools-version: 6.0
//
//  Package.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import PackageDescription

let package = Package(
    name: "LexiDFA",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LexiDFACore", targets: ["LexiDFACore"])
    ],
    targets: [
        .target(
            name: "LexiDFACore",
            path: "LexiDFA",
            exclude: ["App", "Assets.xcassets", "Views", "Visualization"],
            sources: ["Models", "Scanner", "Concurrency"]
        ),
        .testTarget(
            name: "LexiDFACoreTests",
            dependencies: ["LexiDFACore"],
            path: "Tests/LexiDFACoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
