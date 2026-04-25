// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MatrixTetris",
    products: [
        .executable(name: "MatrixTetris", targets: ["MatrixTetris"])
    ],
    targets: [
        .target(name: "MatrixTetrisCore"),
        .executableTarget(
            name: "MatrixTetris",
            dependencies: ["MatrixTetrisCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "MatrixTetrisCoreTests",
            dependencies: ["MatrixTetrisCore"]
        )
    ]
)
