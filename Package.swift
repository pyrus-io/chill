// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "chill",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwaggerDocumentationGenerator", targets: ["SwaggerDocumentationGenerator"]),
        .library(name: "APIRouting", targets: ["APIRouting"]),
        .executable(name: "CLI", targets: ["CLI"])
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.3.0"),
        
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.14.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.13.2"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.47.7"),
        
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.1"),
    ],
    targets: [
        
        .target(
            name: "APIRouting",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        
        .target(
            name: "SwiftTypesExtractor",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten")
            ]
        ),
        
        .target(
            name: "SwaggerDocumentationGenerator",
            dependencies: [
                "SwiftTypesExtractor"
            ]
        ),
        
        .target(
            name: "APIClientGenerator",
            dependencies: [
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "PromiseKit", package: "PromiseKit"),
                .product(name: "SwiftFormat", package: "SwiftFormat"),

                .target(name: "SwaggerDocumentationGenerator"),
            ]
        ),
        
        .target(
            name: "CLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                
                "APIClientGenerator",
                "SwaggerDocumentationGenerator",
                "SwiftTypesExtractor"
            ]
        ),
    ]
)
