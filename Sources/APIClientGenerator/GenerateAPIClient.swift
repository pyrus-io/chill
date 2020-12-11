import Foundation
import Stencil
import PathKit
import SwaggerDocumentationGenerator
import SwiftFormat

public func generateAPIClient(inputPaths: [String], outputPath: String) throws {
    let inputDirectories: [URL] = inputPaths.map { Path($0).absolute().url }
    let packageFile: URL = Path("\(outputPath)/APIClient/Package.swift").absolute().url
    let outputDirectory: URL = Path("\(outputPath)/APIClient/Sources/APIClient").absolute().url
    
    let doc = try DocumentationGenerator.generateOpenAPIDocument(
        readDirectoryUrls: inputDirectories,
        config: .init()
    )
    
    try? FileManager.default.removeItem(atPath: Path("\(outputPath)/APIClient").absolute().url.path)
    
    try generateClientApiEndpoints(doc: doc, in: outputDirectory)
    try generateClientApiModels(doc: doc, in: outputDirectory)
    
    let rootLibPath = URL(fileURLWithPath: #file).deletingLastPathComponent()
    /// Copy over Networking lib
    let networkingPath = rootLibPath
        .appendingPathComponent("Networking")
        .path
    
    try FileManager.default.copyItem(atPath: networkingPath, toPath: outputDirectory.appendingPathComponent("Networking").path)
    
    /// Create Package.Swift file
    let templatePath = rootLibPath
        .appendingPathComponent("utilities")
        .appendingPathComponent("templates")
        .path
    let environment = Environment(loader: FileSystemLoader(paths: [Path(templatePath)]))
    let rendered = try environment.renderTemplate(name: "package.stencil", context: [String: Any]())
    FileManager.default.createFile(
        atPath: packageFile.path,
        contents: rendered.data(using: .utf8),
        attributes: nil
    )
}
