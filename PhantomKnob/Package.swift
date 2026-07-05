// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhantomKnob",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PhantomKnob",
            targets: ["PhantomKnob"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "PhantomKnob",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            path: ".",
            sources: [
                "Model/",
                "ViewModel/",
                "View/",
                "Service/",
                "Control/",
                "Storage/",
            ]
        ),
        .testTarget(
            name: "PhantomKnobTests",
            dependencies: ["PhantomKnob"],
            path: "PhantomKnobTests"
        )
    ]
)
