// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "struct-vapor-endpoints",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwaggerDocumentationGenerator", targets: ["SwaggerDocumentationGenerator"]),
        .library(name: "APIRouting", targets: ["APIRouting"])
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "APIRouting",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt")
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
            name: "DocumentationGeneratorCLI",
            dependencies: [
                "SwaggerDocumentationGenerator"
            ]
        ),
    ]
)
